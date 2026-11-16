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

## Storage — a TTRPG-only subfolder of Kavita's books/ tree, plus a dedicated subfolder for everything else

Grimoire mounts **two** read-only hostPaths from the same haven-data Storage Box docs sub-account SMB mount (see [Forge](../guides/forge.md)):

| Host path                          | Container path   | Purpose                                                                                 |
| ---------------------------------- | ---------------- | --------------------------------------------------------------------------------------- |
| `/mnt/haven-data-docs/books/ttrpg` | `/library/books` | Only the TTRPG-specific subset of Kavita's books tree — see below                       |
| `/mnt/haven-data-docs/ttrpg`       | `/library`       | Grimoire-only content Kavita has no concept of: `maps/`, `tokens/`, `audio/`, `models/` |

`/mnt/haven-data-docs/books/ttrpg` is bind-mounted directly at `/library/books` inside Grimoire's container. Per upstream's [FAQ](https://github.com/hunter-read/grimoire/blob/main/docs/faq.md#the-scanner-finds-no-books-after-i-reorganized-my-library), Grimoire's scanner looks for a `books/` subfolder at the root of its library mount — mounting `books/ttrpg` at exactly that path means Grimoire indexes only the TTRPG-specific PDFs living there, sharing the exact same files Kavita also sees (zero duplication), **without** pulling Kavita's entire ~20K-book general-reference library into Grimoire's index too. Kavita's own mount is unaffected — it still reads the whole `books/` tree at its own `/library` root; this is purely an additional, narrower read-only mount on Grimoire's side.

**Folder convention**: TTRPG-specific books live under `books/ttrpg/<system>/...` (e.g. `books/ttrpg/D&D 5e/core/Players Handbook.pdf`) within the same physical tree Kavita already reads — moving a book there doesn't remove it from Kavita, it just also becomes visible to Grimoire. Move/organize TTRPG PDFs there via Nextcloud or directly on the Storage Box (see [Adding library content](#adding-library-content) below), then trigger a rescan in both Kavita and Grimoire.

The dedicated `ttrpg/` subfolder (distinct from `books/ttrpg/` above — same name, different tree) is Grimoire-only — Kavita has no maps/tokens/audio/3D-model concept, so this is where genuinely new content lives, organized per upstream's [Library structure](https://github.com/hunter-read/grimoire/blob/main/docs/library-structure.md) doc (top-level `maps/`, `tokens/`, `audio/`, `models/` — no `books/` needed here, that comes from the shared mount above).

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
3. From **Settings**, confirm the library has picked up content under `/library` — this should already include any books placed under `/mnt/haven-data-docs/books/ttrpg` (mapped to `/library/books` — see [Storage](#storage--a-ttrpg-only-subfolder-of-kavitas-books-tree-plus-a-dedicated-subfolder-for-everything-else) above), plus anything already placed under `/mnt/haven-data-docs/ttrpg`. Trigger a scan if needed.

### Adding library content

Grimoire's own file manager is unavailable here (both mounts are read-only — see [Storage](#storage--a-ttrpg-only-subfolder-of-kavitas-books-tree-plus-a-dedicated-subfolder-for-everything-else) above). Books need to be moved/placed under `/mnt/haven-data-docs/books/ttrpg/<system>/...` to become visible in Grimoire — they'll still show up in Kavita too, since it's the same physical `books/` tree, just no longer indexed by Grimoire until they're specifically under the `ttrpg/` subfolder (see [Storage](#storage--a-ttrpg-only-subfolder-of-kavitas-books-tree-plus-a-dedicated-subfolder-for-everything-else)'s folder convention note above). For new maps/tokens/audio/3D-models, files must land directly on `/mnt/haven-data-docs/ttrpg`, the same way Kavita's `books/` and Jellyfin's `media/` folders are populated: via the **Nextcloud** app (already SSO-logged-in), using an External Storage-mounted folder that points at this path, or by copying files directly onto the Storage Box. Organize per upstream's [Library structure](https://github.com/hunter-read/grimoire/blob/main/docs/library-structure.md) doc (top-level `maps/`, `tokens/`, `audio/`, `models/`). Trigger a scan from Grimoire's own dashboard, or wait for its scheduled scan.

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

**Exception**: household `admins` group members are automatically treated as Grimoire `admin` too (`mapping-grimoire-groups`/`mapping-grimoire-permissions` both check `"admins" in groups` as well as `"grimoire-admin"`) — no separate `grimoire-admin` membership needed for them.

**Role precedence — OIDC always wins on next login**: an admin can change a user's role directly in Grimoire's own **Settings → Users**, but for OIDC-authenticated accounts this is only ever temporary — `_resolve_user` re-syncs the role from the groups claim on **every** OIDC login (the one exception: it won't demote the sole remaining `admin`). To durably change an OIDC user's Grimoire role, change their Authentik group membership, not their role inside Grimoire directly. Manual role edits in Settings → Users only stick for local (non-OIDC) accounts.

**Default role is `player`, never `gm`**: per Grimoire's own `_resolve_user`, a newly auto-registered OIDC account only gets `role_from_groups or "player"` — so without a matching group it falls back to `player`, **not** `gm`. In this repo's config, `OIDC_GROUPS_CLAIM` is set, so the fallback path doesn't even apply — an account with no matching `grimoire-*`/`admins` group is rejected outright at login (`"no matching group in OIDC claims"`) rather than silently landing as `player`.

Two custom Authentik scope mappings (`mapping-grimoire-groups`, `mapping-grimoire-permissions`) translate group membership into the exact claim shapes Grimoire expects:

- **Grimoire Groups** (scope `groups`) → returns `{"groups": ["admin"|"gm"|"player", ...]}` from `grimoire-admin`/`grimoire-gm`/`grimoire-player` membership.
- **Grimoire Permissions** (scope `permissions`) → returns `{"permissions": {"viewNSFW": true|false}}`, true for `grimoire-admin` or `nsfw` group members.

Both are attached to Grimoire's OAuth2 Provider's Advanced Protocol Settings → Scopes automatically by the blueprint.

### Automated wiring

1. **Authentik side**: the blueprint creates the OAuth2 Provider + Application for Grimoire (client ID `grimoire`, gated by `policy-group-gaming` — the `gaming` group (or `admins`), **not** the blanket family `policy-group-members` every other app uses, since Grimoire's real audience is specifically people invited to the TTRPG campaign, not the general family/friends circle — see [Access — the gaming group](#access--the-gaming-group) below — `issuer_mode: per_provider` same strict-issuer pattern as every other app in this repo) every time `deploy-hearth-config.yml` runs. `GRIMOIRE_SSO_CLIENT_SECRET` is generated by strata and stored in Infisical (see `config/environment.yaml`).
2. **Grimoire side**: `config/forge/modules/grimoire.yaml` pins `OIDC_ENABLED`, `OIDC_ISSUER_URL` (`https://auth.huybrechts.xyz/application/o/grimoire/`), `OIDC_CLIENT_ID`, `OIDC_GROUPS_CLAIM`/`OIDC_PERMISSIONS_CLAIM`, `OIDC_MATCH_BY: email`, and `OIDC_AUTO_REGISTER: "true"` as plain Helm values. `OIDC_CLIENT_SECRET` is sourced via `secretKeyRef` from the `grimoire-secrets` K8s Secret (module `config/forge/modules/grimoire-secrets.yaml`, chart `services/forge/grimoire-secrets/`) — the same "dedicated tiny Secret-only chart" pattern used by `nextcloud-secrets`/`homarr-secrets`, since a hand-authored chart's own `env:` dict isn't a safe place for a literal secret value in the rendered manifest.
3. Once deployed, Grimoire's `/login` page shows an "Sign in with Authentik" button, and `OIDC_ENABLED`/`OIDC_ISSUER_URL`/etc. show up read-only in Settings → Authentication (env-pinned fields are locked in the UI).

### Redirect URI — path is fixed by Grimoire

Unlike Kavita's ASP.NET Core app (`/signin-oidc`), Grimoire's OIDC callback path is fixed at `/api/auth/openid/callback` (per upstream's `docs/oidc.md`). The blueprint registers `https://grimoire.huybrechts.xyz/api/auth/openid/callback`, matching `BASE_URL`. **Confirmed live (2026-09-24)**: the redirect_uri round-trips successfully (no "Redirect URI Error" from Authentik) — the first live login attempt got all the way to Grimoire's own post-login group-claim check (see [Still open](#still-open)), confirming the scheme/path match.

### Access — the `gaming` group

Grimoire's Authentik **Application** access is gated by `policy-group-gaming` (grants access to the `gaming` group **or** `admins`) instead of the blanket `policy-group-members` policy every other family app uses. This is deliberate: Grimoire's real audience is specifically the people invited to play in the TTRPG campaign — not necessarily the same set as "family/friends" generally — and it lets you selectively include or exclude individual family members from this one app without touching the family-wide groups. `gaming` is scoped to that purpose (not "grimoire-users") so any future gaming-adjacent app can reuse the same group/policy.

Assigning someone to `gaming` only controls **whether they can attempt SSO login at all** — it has no bearing on their Grimoire role (`admin`/`gm`/`player`), which comes from the separate `grimoire-*` groups above. A person typically needs **both**: `gaming` (or `admins`) to pass the application policy, plus `grimoire-player` (or `-gm`/`-admin`) to get past the groups-claim check once logged in.

**No Authentik self-registration exists in this repo** (confirmed — no enrollment/invitation flow is configured in the blueprint), so every account has to be created manually by an admin (Authentik's own Directory → Users → Create) before anyone can log in — deliberate, uniform, no random signups.

**SSO-only, no local Grimoire accounts (2026-09-25 decision)**: `ALLOW_PASSWORD_AUTHENTICATION: "false"` is set so *everyone* goes through Authentik — no local username/password login path exists day-to-day, keeping a single uniform access story instead of two parallel ones. `OIDC_AUTO_LAUNCH: "true"` redirects `/login` straight to Authentik so there's no dead local-login form to skip past (append `?autoLaunch=0` to the URL to bypass it if ever needed). Two things this doesn't affect: (1) Grimoire's own first-run admin bootstrap always requires a username/password regardless of this setting — that's a one-time exception, not a standing login path; (2) this is a **global** switch — there is no way to allow it for just one user. **Keep that original first-run admin password documented somewhere safe (e.g. Bitwarden)** — it's the only recovery path if Authentik itself is ever down: temporarily unset `ALLOW_PASSWORD_AUTHENTICATION` (or set it `"true"`) and redeploy.

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
