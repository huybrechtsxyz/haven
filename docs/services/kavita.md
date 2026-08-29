# Kavita

> Kavita — PDF/EPUB/comic library server, self-hosted on Forge (k3s).

## Overview

Kavita runs on **Forge** (Hetzner CPX41, k3s), in the shared `documents` Kubernetes namespace alongside Nextcloud. See [Forge](../guides/forge.md) for the node-level overview and [Nextcloud](./nextcloud.md) for the sibling app it shares files with.

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once with `configure_smb: true`, so the haven-data Storage Box's docs sub-account is SMB-mounted at `/mnt/haven-data-docs` on the host, and a DNS A record for `books.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## What gets deployed

| Item      | Value                                                                                                                                               |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image     | `lscr.io/linuxserver/kavita` (LinuxServer.io's actively-maintained image) — **tag not yet verified against a live source, see "Still open" below**  |
| Namespace | `documents` (Kubernetes), module file `config/forge/modules/kavita.yaml`                                                                            |
| Ingress   | Traefik (`className: traefik`), host `books.{domain}`, TLS via cert-manager (`letsencrypt-staging` initially — see [TLS](#tls--cert-manager) below) |

No official Helm chart exists for Kavita (confirmed via a code search across the `Kareadita` GitHub org — no results) — deployed via a local chart at `services/forge/kavita/`.

---

## Storage — shares the haven-data docs mount with Nextcloud

Kavita reads from `/mnt/haven-data-docs/books` (hostPath, **read-only**) — a subpath of the same haven-data Storage Box docs sub-account SMB mount (see [Forge](../guides/forge.md)) that Nextcloud's External Storage also points at. Kavita never renames or reorganizes what it finds — it only indexes/scans — which is exactly why it's safe to share the same files Nextcloud also organizes (unlike Paperless-ngx, which takes ownership of ingested documents and would need its own separate storage).

Kavita's own config/database is separate, local-disk storage (`persistence.config`, `local-path` PVC, 5Gi) — not part of the shared tree.

---

## TLS — cert-manager

Kavita's chart (`services/forge/kavita/templates/ingress.yaml`) supports `ingress.annotations` and `ingress.tls`, wired up the same way as Jellyfin/Immich/Nextcloud. `config/forge/modules/kavita.yaml` currently sets `cert-manager.io/cluster-issuer: letsencrypt-staging` — `books.huybrechts.xyz` has never had a cert issued before, so it needs its own HTTP-01 challenge to succeed at least once via staging before switching to prod (rate-limited to 5 certs/domain/week).

**Rollout steps** (same staging-first pattern as every other Forge app):

1. Deploy with `letsencrypt-staging` (already the current setting).
2. Confirm `kubectl describe certificate books-tls -n documents` shows `Ready: True`.
3. Switch the annotation in `config/forge/modules/kavita.yaml` to `letsencrypt-prod` and redeploy.
4. Re-verify `Ready: True` against the prod issuer before considering this done.

---

## First login

Kavita has no pre-seeded admin account (unlike Nextcloud's `NEXTCLOUD_ADMIN_PASSWORD` env var) — the **first person to open the site becomes the admin**:

1. Visit `http://books.huybrechts.xyz`.
2. Since no users exist yet, Kavita shows its first-run setup screen instead of a login form — create the initial admin account there (username + password of your choice).
3. That account is granted the admin role automatically (first registered user only — every subsequent signup is a normal user unless promoted).
4. From **Settings → Users**, invite/create accounts for other family members if you want more than one local account, or rely on SSO (see below) once it's configured.
5. From **Settings → Libraries**, confirm a library exists pointing at `/library` (mapped from `/mnt/haven-data-docs/books` — see [Storage](#storage--shares-the-haven-data-docs-mount-with-nextcloud) above) and that a scan has picked up content. `/config` is Kavita's own database/settings storage — not a library path, don't pick it in the folder browser.

### Adding books

Kavita has no upload feature of its own, same as Jellyfin — files must land directly on `/mnt/haven-data-docs/books`. The easiest way: open the **Nextcloud** app (iOS/iPadOS or web, already SSO-logged-in) and use the **"Books"** folder — an External Storage mount Nextcloud exposes straight into this same path (see [nextcloud.md](./nextcloud.md#adding-media-for-jellyfin-and-books-for-kavita)). Files land exactly where Kavita's own library scan looks — trigger one from Kavita's Dashboard, or wait for its scheduled scan.

---

## SSO — Authentik OIDC (native)

Unlike Jellyfin (needs a third-party plugin + a UI-minted API key) or Nextcloud (needs the `user_oidc` app + an `occ` command), Kavita has **native OIDC support built into its ASP.NET Core backend** (`Kavita.Common.Configuration.OidcSettings` — a plain `Authority`/`ClientId`/`Secret`/`CustomScopes` block). There's no admin-UI toggle and no REST API for it — Kavita reads this block once, at process startup, from `config/appsettings.json` on its own config PVC.

**Automated on the Authentik + appsettings.json side**, once `KAVITA_SSO_CLIENT_SECRET` exists in Infisical (it's a value we generate ourselves — see `config/environment.yaml` — not something that has to come from Kavita's own UI). **One manual one-time step is still required** (see below) — the "zero manual steps" framing this section originally used was wrong; correcting it here.

1. **Authentik side**: `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Kavita (client ID `kavita`, `members` group policy, `issuer_mode: per_provider` — same strict-issuer fix already applied to Jellyfin/Nextcloud/Immich) every time `deploy-hearth-config.yml` runs.
2. **Kavita side**: `.github/workflows/deploy-forge-deploy.yml` copies `/config/appsettings.json` out of the running pod after every Helm deploy, merges in the `OpenIdConnectSettings` block (`kubectl cp` + `jq`, run on the GitHub Actions runner — not inside the container, since the LinuxServer.io image isn't guaranteed to have `jq`), copies it back, and only restarts the pod (`kubectl rollout restart`) if the file actually changed — because Kavita only reads this file once at startup, a plain file edit with no restart wouldn't take effect. Skips silently if `KAVITA_SSO_CLIENT_SECRET` isn't resolvable yet.
3. Once deployed, `/Oidc/login` and `/Oidc/logout` become active and Kavita's own login page should surface an OIDC sign-in option.

**Known behavior — confirmed live (2026-08-29)**: Kavita's own ASP.NET Core OIDC handler sends `redirect_uri=https://books.huybrechts.xyz/signin-oidc` even though Traefik terminates TLS and forwards plain HTTP to the pod — confirmed by inspecting the actual failed authorize request the first time SSO was tried (Authentik's "Redirect URI Error" showed the exact `redirect_uri` query param). This is the opposite of what was originally assumed here (that Kavita, like Jellyfin's plugin without `schemeOverride`, would keep generating `http://`) — Kavita's forwarded-headers scheme detection is evidently trusting Traefik in this cluster (exact mechanism not fully diagnosed, but the live behavior is what matters). The blueprint's `redirect_uris` entry is `https://books.huybrechts.xyz/signin-oidc` to match.

If Kavita's own hostname/ingress ever changes, re-verify this the same way: attempt a login, capture the failing `redirect_uri=` query param from the browser URL bar, and make sure it still matches the blueprint's registered value exactly (`matching_mode: strict`).

### One-time manual step — enable account provisioning

Getting past the redirect_uri check isn't the whole story — the first real login attempt then failed with **"no matching account found"**. Root cause: Kavita has a **second, database-backed OIDC settings block** (`ServerSettingDto.OidcConfig`, configured through Kavita's own admin UI — Settings → OIDC — not through `appsettings.json`), separate from the `Authority`/`ClientId`/`Secret` block we automate. Per `Kavita.Services/OidcService.cs`'s `LoginOrCreate` flow: a login only succeeds if there's a matching local user by OIDC ID, by exact email match (against an account with no `OidcId` set yet), or if `OidcConfig.ProvisionAccounts` is enabled (allows auto-creating a new local account from the SSO login). This setting defaults to off and nothing in the CI automation touches it, since it's a runtime admin preference, not infrastructure config.

**Fix applied**: logged into Kavita locally (the first-run admin account) → **Settings → OIDC** → enabled **Provision Accounts** → confirmed the **Authority / Client ID / Secret** fields shown there match what's patched into `appsettings.json` (`https://auth.huybrechts.xyz/application/o/kavita/`, `kavita`, the `KAVITA_SSO_CLIENT_SECRET` value) → retried login.

This is a genuinely manual, one-time step (no stable Kavita AuthKey exists yet to script it via `POST /api/Settings`, the way Jellyfin's API key automates its own registration) — same category of exception as Jellyfin's one unavoidable manual step, just a different shape (a settings toggle instead of an API key).

**Also required in the same Settings → OIDC screen — Default Roles / Default Libraries**: enabling `ProvisionAccounts` alone isn't enough. `OidcConfigDto.DefaultRoles` and `DefaultLibraries` both default to an **empty list** (confirmed directly in Kavita's source, `Kavita.Models/DTOs/Settings/OidcConfigDto.cs`), and `SetDefaults()` only assigns them when `SyncUserSettings` is off (the default). Leaving `Default Roles` empty means a newly auto-provisioned account gets **zero roles — including no `Login` role** — which Kavita's own `AccountController.Login` treats identically to an admin-disabled account (`"your account has been disabled"` / `"not authorized to see this view"`). Fix:
- Set **Default Roles** to at least `Login` (plus `Download`/`Bookmark`/`Change Password` for a normal family member, or `Admin` if this account should be a full admin).
- Set **Default Libraries** to whichever library the account should see (e.g. the Books library) — otherwise it can log in but sees nothing.
- Any account that already got auto-created *before* these defaults were set needs its roles/libraries fixed manually, once, via **Settings → Users** — setting the defaults only affects future provisioning, not retroactively.

> **Design note**: [authentik.md](./authentik.md#authentication-strategy) originally scoped Kavita as local-credentials-only ("single-user reader, no family access needed"). This SSO wiring supersedes that — update that table if/when SSO login is confirmed working end-to-end.

### Password login fallback — SSO-only isn't role-scoped

Kavita has an `OidcConfig.DisablePasswordAuthentication` flag (confirmed in `AccountController.Login`), but it's a **global** switch — enabling it blocks password-based login for *every* account, admin included, with no per-role exception. The only bypass when it's on is logging in via an **Auth Key** instead of a password (`Settings → Manage Auth Keys`).

In practice this repo doesn't need that toggle: SSO-auto-provisioned accounts are created with **no password set at all** (`userManager.CreateAsync(user)`, no password argument), so family members created through SSO already can't fall back to a password unless someone manually sets one for them. The original local admin account (from [First login](#first-login)) keeps its normal password as the recovery path if Authentik is ever down. If you do want the blunt global lock later, create an Auth Key for the admin account first — otherwise there's no recovery path left if Authentik goes down.

---

## Verification checklist

- [ ] `https://books.{domain}` — Kavita loads over TLS (staging cert initially — browser will warn until switched to `letsencrypt-prod`)
- [ ] `kubectl describe certificate books-tls -n documents` shows `Ready: True`
- [ ] Library scan picks up files under `/mnt/haven-data-docs/books`
- [ ] Confirm the actual current LinuxServer.io image tag before first deploy
- [ ] First-run admin account created (see [First login](#first-login))
- [ ] `Provision Accounts` enabled under Kavita's Settings → OIDC, with **Default Roles** including `Login` and **Default Libraries** set (see [SSO's one-time manual step](#one-time-manual-step--enable-account-provisioning))
- [ ] Authentik SSO provider registered and "Sign in with SSO" (or equivalent) works end-to-end

---

## Still open

- TLS is on `letsencrypt-staging` pending a live `Ready: True` confirmation — switch to `letsencrypt-prod` once verified (see [TLS](#tls--cert-manager) above)
- Image tag needs a live-source verification pass (LinuxServer.io's docs site and the Kavita wiki both failed to render via automated fetch when this module was authored — used well-established general knowledge instead of a live-verified source)
- SSO redirect_uri is now `https://` (confirmed correct 2026-08-29, see [SSO](#sso--authentik-oidc-native)) — pending a follow-up login test after redeploying `22 - Hearth - Config` with the fixed blueprint, to confirm the "Redirect URI Error" is actually resolved
- `Provision Accounts` is a manual, per-instance admin-UI toggle (Settings → OIDC) — not automated by CI. If Kavita's config PVC is ever recreated from scratch, this must be re-enabled manually before SSO logins work again. **Default Roles and Default Libraries must be set in the same screen** — leaving them empty silently creates roleless/library-less accounts that look "disabled" (see [SSO's one-time manual step](#one-time-manual-step--enable-account-provisioning)).
