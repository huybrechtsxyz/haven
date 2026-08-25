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

| Item      | Value                                                                                                        |
| --------- | ------------------------------------------------------------------------------------------------------------ |
| Chart     | `nextcloud` from the official community repo, `https://nextcloud.github.io/helm`                             |
| Version   | `9.2.6` (chart), appVersion `v34.0.3`                                                                        |
| Namespace | `documents` (Kubernetes), module file `config/forge/modules/nextcloud.yaml`                                  |
| Database  | PostgreSQL — own single-pod instance (`nextcloud-postgres` module), not the chart's bundled Bitnami subchart |
| Cache     | Redis — own single-pod instance (`nextcloud-redis` module), for memory caching + file locking                |
| Ingress   | Traefik (`className: traefik`), host `drive.{domain}`, no TLS yet                                            |

The official Docker image supports **fully automated initial admin setup** via env vars (`NEXTCLOUD_ADMIN_USER`/`PASSWORD` + database connection vars) — no manual first-boot wizard needed, unlike Jellyfin/Portainer.

---

## Storage

`/mnt/haven-docs` (the same host path `rclone-mount` publishes) is mounted into the Nextcloud pod via the chart's own `extraVolumes`/`extraVolumeMounts` support (its README's own documented example is literally "connecting a legacy NFS volume... configured in External Storage" — exactly this use case). Nextcloud's own primary data directory (`persistence`, `local-path` PVC, 8Gi) is separate, small, local-disk storage — unrelated to the shared tree.

---

## SSO + RBAC — Authentik via `user_oidc`

The Authentik side is **already automated** — `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Nextcloud (client ID `nextcloud`, `members` group policy) every time `deploy-hearth-config.yml` runs, using the `NEXTCLOUD_SSO_CLIENT_SECRET` Infisical secret.

The Nextcloud side needs two `occ` commands — **not yet automated**, no Ansible/Job wired up for this yet:

```bash
# 1. Install the official user_oidc app
occ app:install user_oidc

# 2. Register the Authentik provider — group-provisioning maps Authentik's
#    admins/parents/members groups into Nextcloud groups automatically
occ user_oidc:provider authentik \
  --clientid=nextcloud \
  --clientsecret=<NEXTCLOUD_SSO_CLIENT_SECRET> \
  --discoveryuri=https://auth.huybrechts.xyz/application/o/nextcloud/.well-known/openid-configuration \
  --group-provisioning=1
```

Unlike Jellyfin's SSO plugin (which needs an admin API key obtained through a first-run web wizard), these `occ` commands can run directly against the pod (`kubectl exec`) with no separate bootstrap — a good candidate for eventual Ansible automation.

---

## External Storage setup (also not yet automated)

Once `/mnt/haven-docs` is mounted into the pod (already done, see Storage above), the External Storage app needs to be told to use it:

```bash
occ files_external:create "Family Documents" local null::null -c datadir=/mnt/haven-docs
```

Also not yet scripted into any Ansible playbook — a manual/one-time step for now, same as the SSO registration above.

---

## Secrets

| Secret                        | Store     | Used by                                                                                                 |
| ----------------------------- | --------- | ------------------------------------------------------------------------------------------------------- |
| `NEXTCLOUD_ADMIN_PASSWORD`    | Infisical | Initial admin account (auto-configured at container startup)                                            |
| `NEXTCLOUD_DB_PASSWORD`       | Infisical | `nextcloud-postgres` + Nextcloud's `externalDatabase.password`                                          |
| `NEXTCLOUD_REDIS_PASSWORD`    | Infisical | `nextcloud-redis` + Nextcloud's `externalRedis.password`                                                |
| `NEXTCLOUD_SSO_CLIENT_SECRET` | Infisical | Authentik's Nextcloud OAuth2 provider (automated) + the `occ user_oidc:provider` command above (manual) |

---

## Verification checklist

- [ ] `http://drive.{domain}` — Nextcloud loads (plain HTTP until TLS is wired up)
- [ ] Admin login works with the auto-configured admin account
- [ ] `user_oidc` installed and Authentik provider registered — SSO login works
- [ ] Authentik groups (admins/parents/members) map correctly into Nextcloud groups
- [ ] External Storage mount shows `/mnt/haven-docs` contents, real filenames/paths preserved
- [ ] Desktop sync client / mobile app can connect

---

## Still open

- No TLS/cert-manager on Forge yet — Nextcloud is HTTP-only for now
- `forge-deploy.yml` (the Ansible playbook that would run `helm upgrade`) doesn't exist yet
- `user_oidc` app install + Authentik provider registration — manual `occ` commands, not automated
- External Storage mount configuration — manual `occ` command, not automated
- Paperless-ngx (separate bucket, ingest-then-own workflow) not started — different use case, doesn't share this tree
