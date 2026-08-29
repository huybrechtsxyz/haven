# Nextcloud

> Nextcloud — family document archive & browsing layer, self-hosted on Forge (k3s). Not the live sync drive (that's Infomaniak kDrive) — Nextcloud organizes/shares what's already settled.

## Overview

Nextcloud runs on **Forge** (Hetzner CPX41, k3s), in the shared `documents` Kubernetes namespace alongside Kavita. See [Forge](../guides/forge.md) for the node-level overview and [Kavita](./kavita.md) for the sibling app it shares files with.

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once with `configure_smb: true`, so the haven-data Storage Box's docs sub-account is SMB-mounted at `/mnt/haven-data-docs` on the host, and a DNS A record for `docs.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## Design decision — why Nextcloud, and why External Storage (not Primary Storage)

The goal is replacing Google Drive for daily family use — non-techie-friendly (desktop sync clients, mobile apps, familiar folder UI), RBAC, and OIDC via Authentik. Nextcloud is the strongest fit for all three. But it also needs to satisfy one more constraint: **other apps (Kavita now, Paperless-ngx later) must be able to read the exact same files.**

Nextcloud can store files two very different ways:

| Mode                                                     | What happens on disk                                                   | Other apps can read it?              |
| -------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------ |
| **Primary storage** (Nextcloud owns the store)           | Files stored as opaque, internally-numbered blobs (`urn:oid:12345...`) | ❌ No — meaningless without Nextcloud |
| **External Storage** (Nextcloud mounts an existing path) | Real folder paths and filenames                                        | ✅ Yes                                |

**External Storage (the `local` backend) is the one used here** — it also avoids the "iTunes problem" (an app silently renaming/reorganizing your files into its own internal format). The trade-off: Nextcloud's own version-history UI is less reliable over External Storage than Primary Storage — acceptable here because kDrive (Infomaniak) already handles active/collaborative/versioned work; Nextcloud's role is the *settled* layer (organize, browse, share what's done), not live collaboration.

The mounted path (`/mnt/haven-data-docs`) is a plain SMB/CIFS share from the haven-data Storage Box's docs sub-account, mounted once on the Forge **host** by `forge-init.yml` and bind-mounted into both the Nextcloud and Kavita pods. Nextcloud has no idea it's backed by Storage Box at all — from its perspective it's just a local folder. Because it's a real shared filesystem (not two independent S3 clients), Nextcloud and Kavita simply read/write the same real files with no risk of disagreeing about directory state.

---

## What gets deployed

| Item      | Value                                                                                                                                         |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Chart     | `nextcloud` from the official community repo, `https://nextcloud.github.io/helm`                                                              |
| Version   | `9.2.6` (chart), appVersion `v34.0.3`                                                                                                         |
| Namespace | `documents` (Kubernetes), module file `config/forge/modules/nextcloud.yaml`                                                                   |
| Database  | PostgreSQL — own single-pod instance (`nextcloud-postgres` module), not the chart's bundled Bitnami subchart                                  |
| Cache     | Redis — own single-pod instance (`nextcloud-redis` module), for memory caching + file locking                                                 |
| Ingress   | Traefik (`className: traefik`), host `docs.{domain}`, TLS via cert-manager (`letsencrypt-staging` initially, same pattern as Immich/Jellyfin) |

The official Docker image supports **fully automated initial admin setup** via env vars (`NEXTCLOUD_ADMIN_USER`/`PASSWORD` + database connection vars) — no manual first-boot wizard needed, unlike Jellyfin/Portainer.

---

## Storage

`/mnt/haven-data-docs` (the haven-data Storage Box's docs sub-account, SMB-mounted on the Forge host by `forge-init.yml`) is mounted into the Nextcloud pod via the chart's own `extraVolumes`/`extraVolumeMounts` support (its README's own documented example is literally "connecting a legacy NFS volume... configured in External Storage" — same pattern, different protocol). Nextcloud's own primary data directory (`persistence`, `local-path` PVC, 8Gi) is separate, small, local-disk storage — unrelated to the shared tree.

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
occ files_external:create "Family Documents" local null::null -c datadir=/mnt/haven-data-docs
```

`NEXTCLOUD_SSO_CLIENT_SECRET` is exposed to the hook as a plain container env var (`extraEnv`), same plaintext-substitution pattern already used for the admin/DB/Redis passwords in this file.

**Also proactively fixed** (learned from Jellyfin's SSO debugging this session): Traefik terminates TLS and forwards plain HTTP to the pod, so without telling Nextcloud to trust the proxy, it would generate `http://` URLs for OIDC redirects and break SSO the same way Jellyfin's did initially. `extraEnv` sets `TRUSTED_PROXIES=10.42.0.0/16` (k3s's pod CIDR), `OVERWRITEPROTOCOL=https`, and `OVERWRITECLIURL=https://docs.huybrechts.xyz` — the chart already enables `reverse-proxy.config.php` by default, which reads these.

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

- [ ] `https://docs.{domain}` — Nextcloud loads and is reachable from a browser
- [ ] Admin login works with the auto-configured admin account
- [ ] `user_oidc` installed and Authentik provider registered automatically — SSO login works
- [ ] Authentik groups (admins/parents/members) map correctly into Nextcloud groups
- [ ] External Storage mount shows `/mnt/haven-data-docs` contents, real filenames/paths preserved
- [ ] Desktop sync client / mobile app can connect

---

## Still open

- TLS cert: switch `cert-manager.io/cluster-issuer` from `letsencrypt-staging` to `letsencrypt-prod` once `kubectl describe certificate docs-tls -n documents` shows `Ready: True` (same staging-first pattern as Immich/Jellyfin)
- `documents` namespace is active in `config/stack/workspace.yaml` and the haven-data docs SMB mount is now wired in `forge-init.yml`/`forge-config.yml`, but this namespace hasn't been deployed to the live cluster yet — none of the automation above has been exercised for real
- Paperless-ngx (separate bucket, ingest-then-own workflow) not started — different use case, doesn't share this tree
