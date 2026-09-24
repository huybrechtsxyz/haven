# Grimoire

> Grimoire — self-hosted TTRPG library manager (books, maps, tokens, audio, 3D models), self-hosted on Forge (k3s).

## Overview

[Grimoire](https://github.com/hunter-read/grimoire) runs on **Forge** (Hetzner CPX41, k3s), in the shared `documents` Kubernetes namespace alongside Nextcloud and Kavita. See [Forge](../guides/forge.md) for the node-level overview and [Kavita](./kavita.md)/[Nextcloud](./nextcloud.md) for the sibling apps it shares the docs sub-account tree with.

Unlike Kavita (a general PDF/EPUB/comic reader), Grimoire is purpose-built for tabletop RPG collections — it adds a full-text-searchable library across books, battlemaps, tokens, audio, and 3D models, plus per-user campaign tracking (a markdown notes wiki, linked resources, and a UVTT map editor for dynamic-lighting walls/doors/lights).

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once with `configure_smb: true`, so the haven-data Storage Box's docs sub-account is SMB-mounted at `/mnt/haven-data-docs` on the host, and a DNS A record for `grimoire.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## What gets deployed

| Item      | Value                                                                                                                                     |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Image     | `hunterreadca/grimoire:latest` (official image, includes Tesseract OCR — see [image variants](#image-variants) below)                     |
| Namespace | `documents` (Kubernetes), module file `config/forge/modules/grimoire.yaml`                                                                |
| Ingress   | Traefik (`className: traefik`), host `grimoire.{domain}`, TLS via cert-manager (`letsencrypt-prod` — see [TLS](#tls--cert-manager) below) |

No official Helm chart exists for Grimoire — deployed via a local chart at `services/forge/grimoire/`, same pattern as Kavita's.

### Image variants

The default tags (`latest`, pinned releases) include the Tesseract OCR engine so image-only/scanned PDFs are still full-text searchable. A smaller `-slim` variant (e.g. `:slim`) omits Tesseract if OCR isn't needed — not used here, since the point of self-hosting a scanned PDF collection is that older scanned rulebooks stay searchable.

---

## Storage — shares Kavita's books/ folder, plus a dedicated subfolder for everything else

Grimoire mounts **two** read-only hostPaths from the same haven-data Storage Box docs sub-account SMB mount (see [Forge](../guides/forge.md)):

| Host path                    | Container path   | Purpose                                                                                 |
| ---------------------------- | ---------------- | --------------------------------------------------------------------------------------- |
| `/mnt/haven-data-docs/books` | `/library/books` | The **same physical folder Kavita already reads from** — see below                      |
| `/mnt/haven-data-docs/ttrpg` | `/library`       | Grimoire-only content Kavita has no concept of: `maps/`, `tokens/`, `audio/`, `models/` |

`/mnt/haven-data-docs/books` is bind-mounted a **second time**, directly at `/library/books` inside Grimoire's container (in addition to Kavita's own existing mount of the same host path at its own `/library`). Per upstream's [FAQ](https://github.com/hunter-read/grimoire/blob/main/docs/faq.md#the-scanner-finds-no-books-after-i-reorganized-my-library), Grimoire's scanner looks for a `books/` subfolder at the root of its library mount — mounting the shared folder at exactly that path means Grimoire indexes the **identical PDF files** Kavita already serves, with **zero duplication** and no separate upload step. Kavita's own module/mount is completely unaffected by this — it's purely an additional read-only mount on Grimoire's side.

The dedicated `ttrpg/` subfolder is Grimoire-only — Kavita has no maps/tokens/audio/3D-model concept, so this is where genuinely new content lives, organized per upstream's [Library structure](https://github.com/hunter-read/grimoire/blob/main/docs/library-structure.md) doc (top-level `maps/`, `tokens/`, `audio/`, `models/` — no `books/` needed here, that comes from the shared mount above).

Both mounts are read-only — same "apps only read, Nextcloud is where family uploads happen" convention already used for Kavita — so Grimoire's in-app file management (upload/rename/delete) is intentionally unavailable.

Grimoire's own database, full-text search index, and rendered thumbnails/cache are separate, local-disk storage (`persistence.data`, `local-path` PVC, 10Gi) — not part of the shared tree. Back this up the same way Kavita's config PVC is backed up.

---

## TLS — cert-manager

Grimoire's chart (`services/forge/grimoire/templates/ingress.yaml`) supports `ingress.annotations` and `ingress.tls`, wired up the same way as Kavita/Jellyfin/Immich/Nextcloud. `config/forge/modules/grimoire.yaml` was deployed with `cert-manager.io/cluster-issuer: letsencrypt-staging` first (`grimoire.huybrechts.xyz` had never had a cert issued before), then switched to `letsencrypt-prod` (2026-09-24) after confirming the HTTP-01 challenge succeeded via staging.

**Rollout steps** (same staging-first pattern as every other Forge app):

1. Deploy with `letsencrypt-staging` first for a brand-new hostname.
2. Confirm `kubectl describe certificate grimoire-tls -n documents` shows `Ready: True`.
3. Switch the annotation in `config/forge/modules/grimoire.yaml` to `letsencrypt-prod` and redeploy. **Done (2026-09-24).**
4. Re-verify `Ready: True` against the prod issuer — confirm `https://grimoire.huybrechts.xyz` loads without a browser TLS warning.

---

## First login

Grimoire has no pre-seeded admin account by default — the first person to register through the app's sign-up screen becomes the admin, same pattern as Kavita. Alternatively, accounts can be pre-seeded automatically from a `users.json` file (see upstream's [Users and permissions](https://docs.grimoirecodex.org/users-and-permissions) doc) — not wired up in this repo yet.

1. Visit `https://grimoire.huybrechts.xyz`.
2. Register the initial admin account.
3. From **Settings**, confirm the library has picked up content under `/library` — this should already include Kavita's existing books (mapped from `/mnt/haven-data-docs/books` at `/library/books` — see [Storage](#storage--shares-kavitas-books-folder-plus-a-dedicated-subfolder-for-everything-else) above) with no extra step, plus anything already placed under `/mnt/haven-data-docs/ttrpg`. Trigger a scan if needed.

### Adding library content

Grimoire's own file manager is unavailable here (both mounts are read-only — see [Storage](#storage--shares-kavitas-books-folder-plus-a-dedicated-subfolder-for-everything-else) above). **Books already added for Kavita need nothing extra** — they show up in Grimoire automatically since it's the same physical folder. For new maps/tokens/audio/3D-models, files must land directly on `/mnt/haven-data-docs/ttrpg`, the same way Kavita's `books/` and Jellyfin's `media/` folders are populated: via the **Nextcloud** app (already SSO-logged-in), using an External Storage-mounted folder that points at this path, or by copying files directly onto the Storage Box. Organize per upstream's [Library structure](https://github.com/hunter-read/grimoire/blob/main/docs/library-structure.md) doc (top-level `maps/`, `tokens/`, `audio/`, `models/`). Trigger a scan from Grimoire's own dashboard, or wait for its scheduled scan.

---

## SSO — Authentik OIDC (native)

Grimoire has **native OpenID Connect support** (Settings → Authentication, or pinned read-only via `OIDC_*` environment variables — see upstream's [OpenID Connect](https://github.com/hunter-read/grimoire/blob/main/docs/oidc.md) doc). Unlike Kavita, no post-deploy file patching is needed: Grimoire reads its OIDC config from plain env vars at container startup, so a Helm values change + pod restart is the whole rollout.

### Role/permission mapping — dedicated Authentik groups

Grimoire's own `OIDC_GROUPS_CLAIM` only recognizes groups literally named (case-insensitively) `admin`, `gm`, or `player` — this repo's real family groups (`admins`/`parents`/`members`) don't match. Per upstream's [FAQ worked example](https://github.com/hunter-read/grimoire/blob/main/docs/faq.md#how-do-i-configure-oidc-with-authentik), `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates four dedicated groups instead:

| Group             | Purpose                                      |
| ----------------- | -------------------------------------------- |
| `grimoire-admin`  | Full admin access in Grimoire                |
| `grimoire-gm`     | GM role in Grimoire                          |
| `grimoire-player` | Player role in Grimoire                      |
| `nsfw`            | Grants explicit-content access to non-admins |

These are **separate from** the family-wide `admins`/`parents`/`members` groups: the family groups gate *who can attempt SSO into Grimoire at all* (via `policy-group-members`, same as every other app), while the four groups above control *what role Grimoire assigns once logged in*. The blueprint only creates the empty group shells — **assign family members to the appropriate `grimoire-*` group(s) manually in Authentik** (Directory → Groups) before their first login, or they'll auto-register with no matching role.

Two custom Authentik scope mappings (`mapping-grimoire-groups`, `mapping-grimoire-permissions`) translate group membership into the exact claim shapes Grimoire expects:

- **Grimoire Groups** (scope `groups`) → returns `{"groups": ["admin"|"gm"|"player", ...]}` from `grimoire-admin`/`grimoire-gm`/`grimoire-player` membership.
- **Grimoire Permissions** (scope `permissions`) → returns `{"permissions": {"viewNSFW": true|false}}`, true for `grimoire-admin` or `nsfw` group members.

Both are attached to Grimoire's OAuth2 Provider's Advanced Protocol Settings → Scopes automatically by the blueprint.

### Automated wiring

1. **Authentik side**: the blueprint creates the OAuth2 Provider + Application for Grimoire (client ID `grimoire`, `members` group policy gating login attempts, `issuer_mode: per_provider` — same strict-issuer pattern as every other app in this repo) every time `deploy-hearth-config.yml` runs. `GRIMOIRE_SSO_CLIENT_SECRET` is generated by strata and stored in Infisical (see `config/environment.yaml`).
2. **Grimoire side**: `config/forge/modules/grimoire.yaml` pins `OIDC_ENABLED`, `OIDC_ISSUER_URL` (`https://auth.huybrechts.xyz/application/o/grimoire/`), `OIDC_CLIENT_ID`, `OIDC_GROUPS_CLAIM`/`OIDC_PERMISSIONS_CLAIM`, `OIDC_MATCH_BY: email`, and `OIDC_AUTO_REGISTER: "true"` as plain Helm values. `OIDC_CLIENT_SECRET` is sourced via `secretKeyRef` from the `grimoire-secrets` K8s Secret (module `config/forge/modules/grimoire-secrets.yaml`, chart `services/forge/grimoire-secrets/`) — the same "dedicated tiny Secret-only chart" pattern used by `nextcloud-secrets`/`homarr-secrets`, since a hand-authored chart's own `env:` dict isn't a safe place for a literal secret value in the rendered manifest.
3. Once deployed, Grimoire's `/login` page shows an "Sign in with Authentik" button, and `OIDC_ENABLED`/`OIDC_ISSUER_URL`/etc. show up read-only in Settings → Authentication (env-pinned fields are locked in the UI).

### Redirect URI — path is fixed by Grimoire

Unlike Kavita's ASP.NET Core app (`/signin-oidc`), Grimoire's OIDC callback path is fixed at `/api/auth/openid/callback` (per upstream's `docs/oidc.md`). The blueprint registers `https://grimoire.huybrechts.xyz/api/auth/openid/callback`, matching `BASE_URL`. **Confirmed live (2026-09-24)**: the redirect_uri round-trips successfully (no "Redirect URI Error" from Authentik) — the first live login attempt got all the way to Grimoire's own post-login group-claim check (see [Still open](#still-open)), confirming the scheme/path match.

---

## Verification checklist

- [ ] `https://grimoire.{domain}` — Grimoire loads over TLS (staging cert initially — browser will warn until switched to `letsencrypt-prod`)
- [ ] `kubectl describe certificate grimoire-tls -n documents` shows `Ready: True`
- [ ] Library scan picks up Kavita's existing books under `/library/books` and any new content under `/mnt/haven-data-docs/ttrpg`
- [ ] First-run admin account created (see [First login](#first-login))
- [ ] `kubectl get pods -n documents` shows the Grimoire pod healthy (`GET /api/health` readiness/liveness probes passing)
- [ ] `kubectl get secret grimoire-secrets -n documents` exists and `OIDC_CLIENT_SECRET` resolves in the pod's env
- [ ] Family members assigned to the appropriate `grimoire-admin`/`grimoire-gm`/`grimoire-player` (and `nsfw`, if applicable) Authentik groups
- [ ] "Sign in with Authentik" button appears on `/login` and a real login round-trips successfully (watch for a redirect_uri mismatch on the very first attempt — see [Redirect URI](#redirect-uri--path-is-fixed-by-grimoire) above)

---

## Still open

- `grimoire-admin`/`grimoire-gm`/`grimoire-player`/`nsfw` Authentik group membership is manual, per-user — the blueprint only creates empty group shells (see [SSO](#sso--authentik-oidc-native)). **Confirmed live (2026-09-24)**: an account with no group membership gets denied with a "no matching group in OIDC claims"-style error — expected behavior, not a bug. Fix: Authentik → Directory → Groups → `grimoire-admin` (or `grimoire-gm`/`grimoire-player`) → Users tab → add the account, then log out of Grimoire and log back in (the groups claim is only read at login time, an already-open session won't pick up a group change).
- `SECRET_KEY` is left unset (upstream default): Grimoire generates and persists a random key under `DATA_PATH` on first boot, which is fine for a single-replica deployment — revisit only if this ever runs multiple replicas without a shared `DATA_PATH`
- `persistence.data` size (10Gi) is an initial estimate (database + search index + rendered thumbnails/cache) — monitor actual usage and grow the PVC if needed
- Pre-seeded users (`users.json`) not wired up — first-registration-becomes-admin is the only onboarding path today
