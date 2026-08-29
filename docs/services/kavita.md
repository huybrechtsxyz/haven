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
5. From **Settings → Libraries**, confirm a library exists pointing at `/library` (mapped from `/mnt/haven-data-docs/books` — see [Storage](#storage--shares-the-haven-data-docs-mount-with-nextcloud) above) and that a scan has picked up content.

---

## SSO — Authentik OIDC (native)

Unlike Jellyfin (needs a third-party plugin + a UI-minted API key) or Nextcloud (needs the `user_oidc` app + an `occ` command), Kavita has **native OIDC support built into its ASP.NET Core backend** (`Kavita.Common.Configuration.OidcSettings` — a plain `Authority`/`ClientId`/`Secret`/`CustomScopes` block). There's no admin-UI toggle and no REST API for it — Kavita reads this block once, at process startup, from `config/appsettings.json` on its own config PVC.

**Fully automated, zero manual steps**, once `KAVITA_SSO_CLIENT_SECRET` exists in Infisical (it's a value we generate ourselves — see `config/environment.yaml` — not something that has to come from Kavita's own UI):

1. **Authentik side**: `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Kavita (client ID `kavita`, `members` group policy, `issuer_mode: per_provider` — same strict-issuer fix already applied to Jellyfin/Nextcloud/Immich) every time `deploy-hearth-config.yml` runs.
2. **Kavita side**: `.github/workflows/deploy-forge-deploy.yml` copies `/config/appsettings.json` out of the running pod after every Helm deploy, merges in the `OpenIdConnectSettings` block (`kubectl cp` + `jq`, run on the GitHub Actions runner — not inside the container, since the LinuxServer.io image isn't guaranteed to have `jq`), copies it back, and only restarts the pod (`kubectl rollout restart`) if the file actually changed — because Kavita only reads this file once at startup, a plain file edit with no restart wouldn't take effect. Skips silently if `KAVITA_SSO_CLIENT_SECRET` isn't resolvable yet.
3. Once deployed, `/Oidc/login` and `/Oidc/logout` become active and Kavita's own login page should surface an OIDC sign-in option.

**Known limitation — OIDC redirect scheme may still be HTTP even with TLS live**: Kavita's own ASP.NET Core `ForwardedHeaders` handling (`Kavita.Server.Startup`) only trusts individual proxy IPs added to its `KnownProxies` config section — it has no CIDR-range support (unlike Nextcloud's `TRUSTED_PROXIES` env var) and no scheme-override knob (unlike Jellyfin's SSO plugin `schemeOverride`). Traefik's in-cluster pod IP isn't static, so there's no single IP to pin. This means even after TLS is live on the ingress (see [TLS](#tls--cert-manager) above), Kavita may still generate an `http://` redirect_uri unless/until this is addressed. **Do not** flip the Authentik blueprint's `redirect_uris` entry to `https://` until you've confirmed live (e.g. by inspecting the redirect URL during an actual SSO login attempt) that Kavita itself is reporting `https`.

> **Design note**: [authentik.md](./authentik.md#authentication-strategy) originally scoped Kavita as local-credentials-only ("single-user reader, no family access needed"). This SSO wiring supersedes that — update that table if/when SSO login is confirmed working end-to-end.

---

## Verification checklist

- [ ] `https://books.{domain}` — Kavita loads over TLS (staging cert initially — browser will warn until switched to `letsencrypt-prod`)
- [ ] `kubectl describe certificate books-tls -n documents` shows `Ready: True`
- [ ] Library scan picks up files under `/mnt/haven-data-docs/books`
- [ ] Confirm the actual current LinuxServer.io image tag before first deploy
- [ ] First-run admin account created (see [First login](#first-login))
- [ ] Authentik SSO provider registered and "Sign in with SSO" (or equivalent) works end-to-end

---

## Still open

- TLS is on `letsencrypt-staging` pending a live `Ready: True` confirmation — switch to `letsencrypt-prod` once verified (see [TLS](#tls--cert-manager) above)
- OIDC redirect_uri is still registered as `http://` in the Authentik blueprint — do not switch to `https://` until Kavita's own scheme detection is confirmed live (see [SSO](#sso--authentik-oidc-native)'s known limitation above)
- Image tag needs a live-source verification pass (LinuxServer.io's docs site and the Kavita wiki both failed to render via automated fetch when this module was authored — used well-established general knowledge instead of a live-verified source)
- SSO login not yet confirmed working end-to-end in production (automation is in place — see [SSO](#sso--authentik-oidc-native) — but needs a live test pass after the next deploy)
