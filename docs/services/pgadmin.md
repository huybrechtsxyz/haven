# pgAdmin

> pgAdmin 4 — web-based PostgreSQL administration, self-hosted on Forge (k3s), for every Postgres instance in Haven.

## Overview

[pgAdmin](https://www.pgadmin.org/) runs on **Forge** (Hetzner CPX41, k3s), in the shared `system` Kubernetes namespace — same cross-cutting-infra category as cert-manager, Gatus, Homarr, and FileBrowser. Unlike those, pgAdmin is **admin-only**: it gives direct read/write access to every Postgres instance in Haven (Immich, Nextcloud, Firefly III, and any future app's database), so it's gated the same way as WUD/Portainer, not the blanket family policy.

**Prerequisites:**
- `deploy-forge-init.yml` must have run successfully at least once (k3s + Traefik installed).
- The `system` namespace's cert-manager must already be deployed — pgAdmin's ingress relies on its `letsencrypt-staging`/`letsencrypt-prod` `ClusterIssuer`s existing first.
- A DNS A record for `pgadmin.{domain}` pointing directly at Forge's public IP.

---

## What gets deployed

| Item      | Value                                                                                                                                                  |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Chart     | `pgadmin` — local chart (`services/forge/pgadmin`). No official pgadmin-org Helm chart exists; community ones aren't maintained by the project itself. |
| Image     | `dpage/pgadmin4:9.14` (official image, pinned — see [Image versioning](#image-versioning-never-use-latest) below)                                      |
| Namespace | `system` (Kubernetes), module file `config/forge/modules/pgadmin.yaml`                                                                                 |
| Ingress   | Traefik (`className: traefik`), host `pgadmin.{domain}`, TLS via cert-manager (`letsencrypt-prod`)                                                     |
| Storage   | `persistence` PVC, `local-path`, 2Gi — pgAdmin's session data, user files, and its own config database (`pgadmin4.db`)                                 |

---

## Image versioning — never use `:latest`

pgAdmin's own container docs are explicit about this: its config database (`pgadmin4.db`) migrates forward-only, including destructive operations (column drops) with no deprecation cycle. Two consequences baked into this chart:

1. **The image tag is pinned** (`9.14`, confirmed against [Docker Hub](https://hub.docker.com/r/dpage/pgadmin4/tags) 2026-09-27) — re-verify before bumping, and never use `:latest`.
2. **The Deployment strategy is `Recreate`, not the k8s default `RollingUpdate`** (`services/forge/pgadmin/templates/deployment.yaml`). A rolling upgrade would briefly run the old and new pod versions against the same shared PVC — the new pod's startup runs any pending migrations, and the old pod (still serving traffic until Kubernetes terminates it) then queries a schema its ORM no longer understands. `Recreate` terminates the old pod first, at the cost of a few seconds of downtime per upgrade — the supported pattern for this class of app (same reasoning class as why Jellyfin's `config` PVC reset required redoing manual setup — a single shared SQLite-like store with in-place schema migrations).

The container also runs as a **fixed UID/GID 5050** (not configurable like LinuxServer's PUID/PGID) — the Pod's `securityContext` sets `fsGroup`/`runAsUser: 5050` so the PVC stays writable.

---

## Secrets

| Secret                      | Store     | Used by                                                                                                  |
| --------------------------- | --------- | -------------------------------------------------------------------------------------------------------- |
| `PGADMIN_DEFAULT_PASSWORD`  | Infisical | pgAdmin's built-in local admin account (`admin@huybrechts.xyz`) — break-glass login if Authentik is down |
| `PGADMIN_SSO_CLIENT_SECRET` | Infisical | Authentik blueprint's pgAdmin OAuth2Provider + pgAdmin's own `config_local.py` `OAUTH2_CONFIG`           |

---

## TLS — cert-manager

Staging-first pattern, same as every other brand-new hostname in this repo. `pgadmin.huybrechts.xyz`'s `letsencrypt-staging` HTTP-01 challenge succeeded first (confirmed `Ready: True`), then switched to `letsencrypt-prod` (2026-09-28) — `config/forge/modules/pgadmin.yaml` now sets `cert-manager.io/cluster-issuer: letsencrypt-prod`.

Unlike Firefly III/FoundryVTT/RPGKeeper, pgAdmin didn't need to skip straight to `letsencrypt-prod` — it uses real native OAuth2 (browser redirects only), not a forwardAuth middleware making a server-to-server HTTPS call back to this host, so there was no certificate-trust chicken-and-egg problem here.

---

## SSO — Authentik OIDC (native)

pgAdmin has **native OAuth2 support built into its Flask backend** (`config_local.py`'s `OAUTH2_CONFIG` list) — no plugin, no forwardAuth proxy needed. This is a genuinely proven config shape: it's adapted from a real, working Keycloak-backed setup from an earlier (pre-Haven) project of ours, just re-pointed at Authentik's endpoints.

**Authentik side**: `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for pgAdmin (client ID `pgadmin`, `admins` group policy, `issuer_mode: per_provider`) every time `deploy-hearth-config.yml` runs, using the `PGADMIN_SSO_CLIENT_SECRET` Infisical secret.

**pgAdmin side**: `services/forge/pgadmin/templates/configmap.yaml` renders `config_local.py` with the OAuth2 block, mounted at `/pgadmin4/config_local.py`. Uses Authentik's real, provider-agnostic OAuth2 endpoints (`/application/o/authorize/`, `/application/o/token/`, `/application/o/userinfo/`) plus the per-provider issuer path for discovery/logout — the same convention already confirmed working for Immich/Kavita/Grimoire/Gatus's native OIDC integrations.

### Redirect URI — not yet confirmed live

pgAdmin's OAuth2 module (Flask/authlib-based) uses a callback path that can vary by version. The blueprint currently registers `https://pgadmin.huybrechts.xyz/oauth2/authorize` as a best guess. **If the first login attempt fails with a redirect_uri mismatch**, capture the exact failing URL from the browser's address bar (Authentik's "Redirect URI Error" page shows it) and update the blueprint's `redirect_uris` entry to match — same troubleshooting pattern used for every other app in this repo (Kavita, Grimoire, Jellyfin all hit and fixed this exact class of issue on first login).

### Break-glass — `PGADMIN_DEFAULT_PASSWORD`

pgAdmin's container **requires** `PGADMIN_DEFAULT_EMAIL`/`PGADMIN_DEFAULT_PASSWORD` at launch regardless of `AUTHENTICATION_SOURCES` — there's no way to omit the local admin account from the container's startup, even though it's no longer usable to log in (see below).

**Decision (2026-09-28): OIDC-only, local login disabled.** `AUTHENTICATION_SOURCES` is set to `['oauth2']` only (`services/forge/pgadmin/templates/configmap.yaml`) — the local username/password login form no longer appears at all, even though the account technically still exists in pgAdmin's database. This is a deliberate tradeoff: **if Authentik is ever down, there is no way to log into pgAdmin's UI.** The real fallback in that scenario is either:
1. `kubectl exec` directly into the target Postgres pod and use `psql`, bypassing pgAdmin entirely, or
2. Temporarily edit `configmap.yaml` back to `AUTHENTICATION_SOURCES = ['oauth2', 'internal']` and redeploy to restore the local login form.

---

## Verification checklist

- [ ] `https://pgadmin.{domain}` — pgAdmin loads over TLS with a trusted `letsencrypt-prod` certificate
- [ ] `kubectl describe certificate pgadmin-tls -n system` shows `Ready: True`
- [ ] `kubectl get pods -n system` shows the pgAdmin pod healthy
- [ ] Local username/password login form does **not** appear on the login page (confirms `AUTHENTICATION_SOURCES = ['oauth2']` took effect)
- [ ] "Login with Authentik" button appears on the login page and a real login round-trips successfully (watch for a redirect_uri mismatch on the first attempt — see [Redirect URI](#redirect-uri--not-yet-confirmed-live) above)
- [ ] Login is rejected for a non-`admins` account (confirms `policy-group-admins` gating works)
- [ ] Add Immich/Nextcloud/Firefly III's Postgres instances as pgAdmin "Servers" (host = the in-cluster Service DNS name, e.g. `immich-postgres.immich.svc.cluster.local`)

---

## Still open

- Redirect URI not yet live-verified (see above) — first real login attempt will confirm or require a fix.
- No pre-loaded `servers.json` — the Immich/Nextcloud/Firefly III Postgres connections need adding manually via the UI on first use (one-time, per admin user).
- `persistence` size (2Gi) is a generous initial estimate for a config-only database — unlikely to need growing.
