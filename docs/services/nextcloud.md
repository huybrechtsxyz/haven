# Nextcloud

> Nextcloud — family Google Drive replacement, self-hosted on Forge (k3s).

## Overview

Nextcloud runs on **Forge** (Hetzner CPX41, k3s), in the shared `documents` Kubernetes namespace alongside Kavita. See [Forge](../guides/forge.md) for the node-level overview and [Kavita](./kavita.md) for the sibling app it shares files with.

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once, `rclone-mount` (system namespace) must be running so `/mnt/haven-docs` exists on the host, and a DNS A record for `drive.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## Design decision — why Nextcloud, and why External Storage (not Primary Storage)

The goal is replacing Google Drive for daily family use — non-techie-friendly (desktop sync clients, mobile apps, familiar folder UI), RBAC, and OIDC via Authentik. Nextcloud is the strongest fit for all three. But it also needs to satisfy one more constraint: **other apps (Kavita now, Paperless-ngx later) must be able to read the exact same files.**

Nextcloud can back onto S3 two very different ways:

| Mode                                                     | What happens in S3                                                     | Other apps can read it?              |
| -------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------ |
| **Primary storage** (Nextcloud owns the object store)    | Files stored as opaque, internally-numbered blobs (`urn:oid:12345...`) | ❌ No — meaningless without Nextcloud |
| **External Storage** (Nextcloud mounts existing storage) | Real folder paths and filenames                                        | ✅ Yes                                |

**External Storage is the one used here** — it also avoids the "iTunes problem" (an app silently renaming/reorganizing your files into its own internal format). The trade-off: Nextcloud's own version-history UI is less reliable over External Storage than Primary Storage — acceptable here because kDrive (Infomaniak) already handles active/collaborative/versioned work; Nextcloud's role is the *settled* layer (organize, browse, share what's done), not live collaboration.

Nextcloud doesn't talk to S3 directly, either — see [rclone-mount](../guides/forge.md#rclone-mount--shared-filesystem-bridge-for-haven-docs) for why (avoiding two independent S3 clients disagreeing about directory state). Nextcloud, Kavita, and any future app all read/write the *same* real filesystem path.

---

## What gets deployed

| Item      | Value                                                                                                                                          |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Chart     | `nextcloud` from the official community repo, `https://nextcloud.github.io/helm`                                                               |
| Version   | `9.2.6` (chart), appVersion `v34.0.3`                                                                                                          |
| Namespace | `documents` (Kubernetes), module file `config/forge/modules/nextcloud.yaml`                                                                    |
| Database  | PostgreSQL — own single-pod instance (`nextcloud-postgres` module), not the chart's bundled Bitnami subchart                                   |
| Cache     | Redis — own single-pod instance (`nextcloud-redis` module), for memory caching + file locking                                                  |
| Ingress   | Traefik (`className: traefik`), host `drive.{domain}`, TLS via cert-manager (`letsencrypt-staging` initially, same pattern as Immich/Jellyfin) |

The official Docker image supports **fully automated initial admin setup** via env vars (`NEXTCLOUD_ADMIN_USER`/`PASSWORD` + database connection vars) — no manual first-boot wizard needed, unlike Jellyfin/Portainer.

---

## Storage

`/mnt/haven-docs` (the same host path `rclone-mount` publishes) is mounted into the Nextcloud pod via the chart's own `extraVolumes`/`extraVolumeMounts` support (its README's own documented example is literally "connecting a legacy NFS volume... configured in External Storage" — exactly this use case). Nextcloud's own primary data directory (`persistence`, `local-path` PVC, 8Gi) is separate, small, local-disk storage — unrelated to the shared tree.

---

## SSO + RBAC — Authentik via `user_oidc`

The Authentik side is **fully automated** — `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Nextcloud (client ID `nextcloud`, `members` group policy) every time `deploy-hearth-config.yml` runs, using the `NEXTCLOUD_SSO_CLIENT_SECRET` Infisical secret. Uses `issuer_mode: per_provider` and includes the custom `groups` scope mapping (`mapping-group-membership`, shared with Jellyfin's provider) so `user_oidc`'s `--group-provisioning=1` can map Authentik's `admins`/`parents`/`members` groups into Nextcloud groups automatically.

The Nextcloud side is **also fully automated — zero manual steps**, via Nextcloud's own official [docker-entrypoint hook mechanism](https://github.com/nextcloud/docker#auto-configuration-via-hook-folders) (`nextcloud.hooks.post-installation` in `config/forge/modules/nextcloud.yaml`). Unlike Jellyfin (needs a browser-minted admin API key) or Immich (needs an Admin UI step), Nextcloud's own `occ` CLI needs no separate bootstrap credential at all — the hook script runs automatically, exactly once, right after the very first `occ maintenance:install` completes, and is a permanent no-op on every subsequent pod start (Nextcloud's own entrypoint skips "installation" entirely once already installed):

```bash
#!/bin/sh
set -e
occ app:install user_oidc || true
occ user_oidc:provider authentik \
  --clientid=nextcloud \
  --clientsecret="$NEXTCLOUD_SSO_CLIENT_SECRET" \
  --discoveryuri=https://auth.huybrechts.xyz/application/o/nextcloud/.well-known/openid-configuration \
  --group-provisioning=1
occ files_external:create "Family Documents" local null::null -c datadir=/mnt/haven-docs
```

`NEXTCLOUD_SSO_CLIENT_SECRET` is exposed to the hook as a plain container env var (`extraEnv`), same plaintext-substitution pattern already used for the admin/DB/Redis passwords in this file.

**Also proactively fixed** (learned from Jellyfin's SSO debugging this session): Traefik terminates TLS and forwards plain HTTP to the pod, so without telling Nextcloud to trust the proxy, it would generate `http://` URLs for OIDC redirects and break SSO the same way Jellyfin's did initially. `extraEnv` sets `TRUSTED_PROXIES=10.42.0.0/16` (k3s's pod CIDR), `OVERWRITEPROTOCOL=https`, and `OVERWRITECLIURL=https://drive.huybrechts.xyz` — the chart already enables `reverse-proxy.config.php` by default, which reads these.

---

## Secrets

| Secret                        | Store     | Used by                                                                                                                         |
| ----------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `NEXTCLOUD_ADMIN_PASSWORD`    | Infisical | Initial admin account (auto-configured at container startup)                                                                    |
| `NEXTCLOUD_DB_PASSWORD`       | Infisical | `nextcloud-postgres` + Nextcloud's `externalDatabase.password`                                                                  |
| `NEXTCLOUD_REDIS_PASSWORD`    | Infisical | `nextcloud-redis` + Nextcloud's `externalRedis.password`                                                                        |
| `NEXTCLOUD_SSO_CLIENT_SECRET` | Infisical | Authentik's Nextcloud OAuth2 provider + the automated `post-installation` hook's `occ user_oidc:provider` call (both automated) |

---

## Verification checklist

- [ ] `https://drive.{domain}` — Nextcloud loads and is reachable from a browser
- [ ] Admin login works with the auto-configured admin account
- [ ] `user_oidc` installed and Authentik provider registered automatically — SSO login works
- [ ] Authentik groups (admins/parents/members) map correctly into Nextcloud groups
- [ ] External Storage mount shows `/mnt/haven-docs` contents, real filenames/paths preserved
- [ ] Desktop sync client / mobile app can connect

---

## Still open

- TLS cert: switch `cert-manager.io/cluster-issuer` from `letsencrypt-staging` to `letsencrypt-prod` once `kubectl describe certificate drive-tls -n documents` shows `Ready: True` (same staging-first pattern as Immich/Jellyfin)
- `documents` namespace is still pruned out of `config/stack/workspace.yaml` — Nextcloud hasn't been deployed to the live cluster yet, so none of the automation above has been exercised for real
- Paperless-ngx (separate bucket, ingest-then-own workflow) not started — different use case, doesn't share this tree
