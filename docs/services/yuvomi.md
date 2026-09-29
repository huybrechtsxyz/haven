# Yuvomi

> Yuvomi — self-hosted family organizer (tasks, calendar, shopping, meals, budget, pantry, inventory, documents, health, and more), self-hosted on Forge (k3s).

## Overview

[Yuvomi](https://github.com/ulsklyc/yuvomi) (formerly named Oikos) runs on **Forge** (Hetzner CPX41, k3s), in its own `family` Kubernetes namespace. It's a single Node.js/Express + SQLite container bundling 20 independent modules — tasks, calendar, shopping, meals/recipes, pantry, documents, inventory, budget, housekeeping, waste collection, rewards, health, schedule, notes & contacts, birthdays, family/members, reminders, API tokens, backup — replacing what would otherwise be a dozen separate subscription apps.

**Prerequisites:**
- `deploy-forge-init.yml` must have run successfully at least once (k3s + Traefik installed).
- The `system` namespace's cert-manager must already be deployed.
- A DNS A record for `family.{domain}` pointing directly at Forge's public IP.
- An Infomaniak kDrive WebDAV app-specific password and connection URL (see [Still open](#still-open) — not yet confirmed).
- An Immich API key (Settings → API Keys, `asset.read` + `asset.view` permissions).

---

## What gets deployed

| Item      | Value                                                                                                            |
| --------- | ---------------------------------------------------------------------------------------------------------------- |
| Chart     | `yuvomi` — local chart (`services/forge/yuvomi`). No official Helm chart exists upstream (Docker-first project). |
| Image     | `ghcr.io/ulsklyc/yuvomi:v2.69.1` (pinned — see [Image versioning](#image-versioning) below)                      |
| Namespace | `family` (own namespace, dedicated to this app — same weight class as `finance`/`gaming`)                        |
| Ingress   | Traefik (`className: traefik`), host `family.{domain}`, TLS via cert-manager (`letsencrypt-staging` initially)   |
| Storage   | Two PVCs, `local-path`: `data` (2Gi, the SQLite DB) and `backups` (2Gi, Yuvomi's own scheduled snapshots)        |

---

## Image versioning

Pinned to `v2.69.1` (latest at time of writing — this project ships releases every few days, re-verify against [github.com/ulsklyc/yuvomi/releases](https://github.com/ulsklyc/yuvomi/releases) before bumping). Never use `:latest` — same rule as every other app in this repo.

**Deployment strategy is `Recreate`, not `RollingUpdate`** — single SQLite file (`yuvomi.db`) on a `ReadWriteOnce` PVC with forward-only migrations, same reasoning as pgAdmin.

---

## Secrets

| Secret                         | Store     | Used by                                                                                                   |
| ------------------------------ | --------- | --------------------------------------------------------------------------------------------------------- |
| `YUVOMI_SESSION_SECRET`        | Infisical | `SESSION_SECRET` — app refuses to start without a real value                                              |
| `YUVOMI_DB_ENCRYPTION_KEY`     | Infisical | `DB_ENCRYPTION_KEY` — SQLCipher AES-256 at rest. **Cannot be changed once set** — see warning below       |
| `YUVOMI_SSO_CLIENT_SECRET`     | Infisical | Authentik OAuth2Provider + `OIDC_CLIENT_SECRET`                                                           |
| `YUVOMI_WEBDAV_URL`            | Infisical | Infomaniak kDrive WebDAV base URL — confirmed format: `https://<kdrive-id>.connect.kdrive.infomaniak.com` |
| `YUVOMI_WEBDAV_USERNAME`       | Infisical | Infomaniak account username/email                                                                         |
| `YUVOMI_WEBDAV_PASSWORD`       | Infisical | Infomaniak app-specific password — used for both document storage and offsite backup mirroring            |
| `YUVOMI_IMMICH_API_KEY`        | Infisical | Immich API key for the photo screensaver / wall mode feature                                              |
| `INFOMANIAK_EMAIL__*` (4 keys) | Infisical | SMTP — reuses the same shared mailbox as Gatus/Vaultwarden                                                |

### ⚠️ `DB_ENCRYPTION_KEY` is irreversible

Per Yuvomi's own docs: "once set, the key cannot be changed without re-encrypting, and a wrong key aborts the start... a lost or changed key never opens the database again, not by you and not by us." Every other Haven database is encrypted at rest, so this matches that pattern by design — but unlike a rotatable OIDC client secret, **losing this key permanently destroys access to all family data in Yuvomi.** Infisical is the source of truth, but consider an additional out-of-band backup of this specific value (e.g. written down, not just stored digitally in one place).

---

## SSO — Authentik OIDC (OIDC-only, no local login)

`deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Yuvomi (client ID `yuvomi`, `policy-group-members` — everyone, not admin-only, `issuer_mode: per_provider`).

**Decision (2026-09-28): OIDC-only, local password login disabled.** `AUTH_ALLOW_PASSWORD_LOGIN=false` in `config/forge/modules/yuvomi.yaml`.

### ⚠️ Required bootstrap sequence — this is NOT skippable on first deploy

Per Yuvomi's own `.env.example`: `AUTH_ALLOW_PASSWORD_LOGIN=false` "takes effect only once all four `OIDC_*` values above are set AND at least one administrator account is linked to the provider; until then it is ignored... because otherwise nobody could sign in at all - a fresh install creates its first admin through `/setup` with a password."

So the actual first-deploy sequence is:
1. Deploy with `OIDC_*` already fully configured (as this module does) — the app will still show the local `/setup` password form on first visit, because no admin is linked to Authentik yet.
2. Complete `/setup` with a temporary local password to create the first admin account.
3. Log in with Authentik SSO once (links that same admin account to the OIDC identity — likely via matching email).
4. From that point on, `AUTH_ALLOW_PASSWORD_LOGIN=false` actually takes effect and the local login form disappears.

**Recovery if Authentik is ever unreachable**: per the docs, removing/flipping `AUTH_ALLOW_PASSWORD_LOGIN` back and restarting the pod restores the local login form immediately (existing password hashes are untouched, not cleared).

---

## Documents & backups → Infomaniak kDrive (WebDAV)

WebDAV base URL format (confirmed 2026-09-28): `https://<kdrive-id>.connect.kdrive.infomaniak.com` — the numeric kDrive ID (distinct from the Infomaniak org/account ID), not the `ksuite.infomaniak.com/<org-id>/kdrive` web-app URL. The real value lives in Infisical (`YUVOMI_WEBDAV_URL`), never written into this repo.

- **Documents module**: `DOCUMENT_STORAGE_WEBDAV_ENABLED=true`, stores uploaded family documents directly on kDrive instead of a local PVC.
- **Backups**: Yuvomi's own `BACKUP_ENABLED=true` writes consistent scheduled snapshots to the `/backups` PVC — Forge's Borg script safely tars this path (it only ever contains completed snapshot files, unlike a raw tar of the live `/data` SQLite file, which carries the same "torn copy" risk class already flagged for Kavita/RPGKeeper). `WEBDAV_BACKUP_*` additionally mirrors each backup straight to kDrive for genuine offsite redundancy, on top of Haven's own Storage Box Borg repo.

---

## Immich photo screensaver

`IMMICH_URL=https://photos.huybrechts.xyz` + `IMMICH_API_KEY` (create via Immich's own UI: Settings → API Keys, `asset.read` + `asset.view` permissions) enables Yuvomi's "wall mode" tablet display and Immich-backed screensaver when idle. `IMMICH_SCREENSAVER_ALBUM_ID` is left empty (whole library) — set it later to a specific album if desired.

---

## Verification checklist

- [ ] `https://family.{domain}` loads over TLS (staging cert initially)
- [ ] `kubectl describe certificate family-tls -n family` shows `Ready: True`
- [ ] `kubectl get pods -n family` shows the Yuvomi pod healthy, `/health` probe passing
- [ ] Complete `/setup` to create the first admin (local password, one-time)
- [ ] Link that admin account to Authentik SSO, confirm the local login form then disappears on next visit
- [ ] Documents upload lands on Infomaniak kDrive, not local disk
- [ ] A scheduled backup appears both in `/backups` and on kDrive
- [ ] Immich screensaver/wall mode shows real photos

---

## Still open

- Calendar/Contacts sync to kSuite (CalDAV/CardDAV) has no env-var config — only Google/Outlook/Apple have dedicated integration blocks. Set up per-calendar subscriptions manually through Yuvomi's own UI after first login.
- Redirect URI / OIDC callback path taken directly from Yuvomi's `.env.example`, not yet live-verified — same troubleshooting pattern as every other app if the first login attempt fails.
