# Firefly III

> Firefly III — self-hosted personal finance manager (budgets, transactions, recurring bills), self-hosted on Forge (k3s).

## Overview

Firefly III runs on **Forge** (Hetzner CPX41, k3s), in its own `finance` Kubernetes namespace. See [Forge](../guides/forge.md) for the node-level overview.

**Prerequisites:** a DNS A record for `finance.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## What gets deployed

| Item      | Value                                                                                                                                                                                           |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chart     | `firefly` — local chart (`services/forge/firefly`), no official upstream Helm chart exists for Firefly III                                                                                      |
| Image     | `fireflyiii/core` (official image) — pin the tag before first deploy, see the chart's `values.yaml` TODO                                                                                        |
| Namespace | `finance` (Kubernetes), module file `config/forge/modules/firefly.yaml`                                                                                                                         |
| Database  | PostgreSQL — own single-pod instance (`firefly-postgres` module), same pattern as Immich/Nextcloud                                                                                              |
| Storage   | A single `local-path` PVC for file uploads/attachments — no Storage Box mount needed (no shared-file use case like Nextcloud/Kavita/Jellyfin)                                                   |
| Cron      | A native Kubernetes `CronJob` running `php artisan firefly-iii:cron` on a schedule, instead of the docker-compose reference stack's always-running cron sidecar + `STATIC_CRON_TOKEN` HTTP call |
| Ingress   | Traefik (`className: traefik`), host `finance.{domain}`, TLS via cert-manager — **`letsencrypt-prod`, NOT staging** (see the SSO section: a staging cert breaks forwardAuth outright)           |

---

## SSO — Traefik forwardAuth → Authentik (NOT native OIDC)

Every other app on Forge (Immich, Jellyfin, Nextcloud, Kavita) uses native OIDC support built into the app itself. **Firefly III has no OIDC support at all** — confirmed from its own `.env.example`: only `web` (built-in DB auth) or `remote_user_guard` (a header-based mode intended for reverse-proxy-terminated auth like Authelia). This is the **first use of forward-auth SSO in this repo**.

**Status: verified working end-to-end in production (2026-09-08.)** Getting there required three separate fixes beyond the chart itself — all three are prerequisites, and the integration fails with an opaque browser 500 if any one is missing. See "Prerequisites" below.

### Isolating problems: the `sso.enabled` switch

The chart has an `sso.enabled` master switch (`services/forge/firefly/values.yaml`) that gates the Traefik Middleware, the outpost Ingress, the ExternalName Service, and the `router.middlewares` ingress annotation. To determine whether a problem is Firefly itself or the Authentik wiring, set in `config/forge/modules/firefly.yaml`:

```yaml
spec:
  configuration:
    env:
      AUTHENTICATION_GUARD: web   # Firefly's own login screen
    sso:
      enabled: false
```

If Firefly's own login/register page loads, the app, database, ingress, certificate and cron are all fine and the fault is in the forward-auth path. This is exactly how the 2026-09-08 debugging session was scoped. Remember to set both values back together — `sso.enabled: true` with `AUTHENTICATION_GUARD: remote_user_guard`.

### How it works

1. Traefik's `authentik-forwardauth` Middleware (`services/forge/firefly/templates/middleware.yaml`) is attached to Firefly's ingress via the `traefik.ingress.kubernetes.io/router.middlewares` annotation. On every request, Traefik calls out to Authentik's outpost to check the session before forwarding to Firefly.
2. Authentik's Proxy Provider (`deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2`, `mode: forward_single`, `external_host: https://finance.huybrechts.xyz`) issues/validates the session and injects `X-authentik-*` headers (username, email, groups, etc.) once authenticated.
3. Firefly is configured with `AUTHENTICATION_GUARD=remote_user_guard` + `AUTHENTICATION_GUARD_HEADER=HTTP_X_AUTHENTIK_EMAIL` — it trusts the injected header as the user's identity, auto-creating a Firefly user for any email it hasn't seen before (confirmed from `RemoteUserProvider::retrieveById()` source — the first-ever user created this way is automatically granted the `owner` role).
4. Access is gated to the `parents` group (+ `admins`) via `policy-group-parents` in the blueprint — deliberately narrower than the `members` policy used by the shared-family apps, since financial data is more sensitive. Change to `policy-group-members` in the blueprint if kids should have their own accounts too.

### The cross-host outpost routing problem

Authentik's "forward auth (single application)" mode requires `<external_host>/outpost.goauthentik.io/*` — on the **app's own domain** — to be routed to the outpost that actually handles the login callback/session-cookie exchange for that domain. Authentik (and its embedded outpost) runs on **Hearth** (Docker Compose); Firefly runs on **Forge** (k3s) — a different host. To bridge this, the chart adds:

- `templates/service-outpost.yaml` — a plain Kubernetes `ExternalName` Service pointing at `auth.huybrechts.xyz` (with `traefik.ingress.kubernetes.io/service.serversscheme: https` so Traefik connects out over HTTPS).
- `templates/ingress-outpost.yaml` — a second Ingress on the same `finance.huybrechts.xyz` host, routing the `/outpost.goauthentik.io` path prefix to that ExternalName Service, with **no** forwardAuth middleware attached (it must stay reachable unauthenticated, or the login flow would loop).

Traefik gives more-specific path prefixes higher route priority automatically, so this outpost path always wins over the app's catch-all `/` — no explicit priority annotation should be needed, but confirm this with `kubectl describe ingressroute`/Traefik's dashboard if login redirects loop.

### Prerequisites (all three required — confirmed 2026-09-08)

The chart alone is not sufficient. Each of these was a real, separately-diagnosed blocker; missing any one produces a browser 500 with **no corresponding line in Firefly's own access log** (the failure happens in Traefik, upstream of the pod).

1. **A `finance.huybrechts.xyz` site block in Hearth's Caddyfile** (`services/hearth/caddy/Caddyfile`). Traefik preserves the original `Host` header when proxying to an ExternalName Service (`passHostHeader` defaults to true), so Caddy receives `Host: finance.huybrechts.xyz` over a connection whose SNI is `auth.huybrechts.xyz`. Without a matching site block Caddy answers 404 and the outpost is never reached. The block uses `tls internal` because Caddy can never obtain a public certificate for that name (its DNS points at Forge, so ACME HTTP-01 would fail forever) — the internal cert is never actually served, since SNI selects the real `auth` certificate and only the Host header selects the block. Requires a Hearth redeploy (the Caddyfile is bind-mounted per `config/hearth/modules/caddy.yaml`).

2. **Traefik must be allowed to route to ExternalName Services.** Traefik refuses them by default (`Cannot create service error="externalName services not allowed"`), so the outpost Ingress has no backend at all. Enabled cluster-wide via a k3s `HelmChartConfig` written by `deploy/ansible-forge/forge-init.yml` to `/var/lib/rancher/k3s/server/manifests/traefik-config.yaml`. Editing the Traefik Deployment directly does **not** work — k3s reverts it on restart.

3. **A production certificate, not `letsencrypt-staging`.** The forwardAuth middleware makes a server-to-server HTTPS call back to `finance.huybrechts.xyz`, and Go verifies that certificate against the system trust store. A staging cert is signed by an untrusted CA, so every request fails with `x509: certificate signed by unknown authority`. The usual staging-first-then-promote pattern used elsewhere on Forge is **actively broken** for any forward-auth-protected app.

### Verifying the chain

`https://finance.huybrechts.xyz/outpost.goauthentik.io/ping` should return **204 No Content**. That exercises Traefik's outpost route → ExternalName Service → Caddy → Authentik's embedded outpost without involving Firefly or a login flow, so it isolates the plumbing from the application.

### Benign log noise

Firefly logs `production.ERROR: No user in header "HTTP_X_AUTHENTIK_EMAIL".` every ~15 seconds, permanently. Each one pairs with a kubelet health probe (`10.42.0.1 ... "GET /health" 200 ... "kube-probe/..."`) that hits the pod IP directly, bypassing Traefik and therefore carrying no Authentik header. These are **not** a symptom of an SSO problem and will continue even when SSO is working perfectly.

### Confirmed bug + fix (2026-09-07): `AUTHENTICATION_GUARD_HEADER` must be the transformed `$_SERVER` key, not the raw header name

First real deploy hit `production.ERROR: No user in header "X-Authentik-Email"`. Root cause, confirmed by reading `FireflyIII\Support\Authentication\RemoteUserGuard` source directly: the guard reads the configured header via a **literal `request()->server($header)` call — a raw `$_SERVER` lookup, not a normalized HTTP-header lookup**. PHP only exposes real HTTP headers in `$_SERVER` as `HTTP_` + uppercase + underscores (standard CGI convention) — the guard was really designed for Apache's own `REMOTE_USER` variable (set directly by Apache's auth modules, never going through the `HTTP_` transform), so any proxy-injected header must be given in its already-transformed form. Fixed: `AUTHENTICATION_GUARD_HEADER=HTTP_X_AUTHENTIK_EMAIL` (was `X-Authentik-Email`, which never matched anything in `$_SERVER`).

### Open risks / still to confirm

- **Correction to an earlier assumption in this doc**: `remote_user_guard` **does** auto-provision Firefly users — confirmed from `RemoteUserProvider::retrieveById()` source, which creates a new `User` row for any email not already in the database (and grants the very first user created this way the `owner` role). No manual pre-registration step is actually needed.
- **Duplicate-user risk from the isolation test.** If an account was registered through Firefly's own login screen while `sso.enabled: false`, it claimed the `owner` role. If its email differs from the Authentik account's email, the SSO login creates a *second*, non-owner user with an empty ledger. Check `Administration → Users` and delete the stale one if so.
- **The Authentik Proxy provider must be explicitly assigned to the embedded outpost** (`authentik_outposts.outpost` block in the blueprint, field `providers` — not `protocol_providers`, which is silently ignored). This is not automatic for Proxy providers.

---

## Secrets

| Secret                | Store     | Used by                                                                                 |
| --------------------- | --------- | --------------------------------------------------------------------------------------- |
| `FIREFLY_APP_KEY`     | Infisical | Firefly's Laravel `APP_KEY` (session/cookie encryption) — exactly 32 alphanumeric chars |
| `FIREFLY_DB_PASSWORD` | Infisical | `firefly-postgres` + Firefly's `DB_PASSWORD`                                            |

No SSO client secret is needed — forward auth has no app-side OAuth client (see the SSO section above).

---

## Still open

- Confirm the actual current `fireflyiii/core` image tag before first deploy (`values.yaml` currently pins `latest` with a TODO, same caveat as Kavita's image tag when it was first authored).
- SMTP is not wired up yet (`MAIL_MAILER: log`) — Firefly can email bill reminders/reports once configured; reuse the shared Infomaniak mailbox credentials the same way Nextcloud/Vaultwarden/Gatus do, via a small `firefly-secrets` chart if the flat `env:` dict approach isn't sufficient once real SMTP fields are added.
- No DB backup/export strategy specific to Firefly yet — falls under whatever the platform's general Postgres backup story ends up being (not yet designed for any of the Forge Postgres instances).
- The `firefly.png` icon reference in the Authentik blueprint hasn't been confirmed to exist in `homarr-labs/dashboard-icons` — verify or swap via Authentik's UI icon upload.
