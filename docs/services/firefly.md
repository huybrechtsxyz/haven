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
| Ingress   | Traefik (`className: traefik`), host `finance.{domain}`, TLS via cert-manager (`letsencrypt-staging` initially, same pattern as every other Forge app)                                          |

---

## SSO — Traefik forwardAuth → Authentik (NOT native OIDC)

Every other app on Forge (Immich, Jellyfin, Nextcloud, Kavita) uses native OIDC support built into the app itself. **Firefly III has no OIDC support at all** — confirmed from its own `.env.example`: only `web` (built-in DB auth) or `remote_user_guard` (a header-based mode intended for reverse-proxy-terminated auth like Authelia). This is the **first use of forward-auth SSO in this repo** and has real open risks not yet exercised live — read this whole section before deploying.

### How it works

1. Traefik's `authentik-forwardauth` Middleware (`services/forge/firefly/templates/middleware.yaml`) is attached to Firefly's ingress via the `traefik.ingress.kubernetes.io/router.middlewares` annotation. On every request, Traefik calls out to Authentik's outpost to check the session before forwarding to Firefly.
2. Authentik's Proxy Provider (`deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2`, `mode: forward_single`, `external_host: https://finance.huybrechts.xyz`) issues/validates the session and injects `X-authentik-*` headers (username, email, groups, etc.) once authenticated.
3. Firefly is configured with `AUTHENTICATION_GUARD=remote_user_guard` + `AUTHENTICATION_GUARD_HEADER=X-Authentik-Email` — it trusts the injected header as the identity of an **already-existing** Firefly user (remote_user_guard does **not** auto-provision accounts).
4. Access is gated to the `parents` group (+ `admins`) via `policy-group-parents` in the blueprint — deliberately narrower than the `members` policy used by the shared-family apps, since financial data is more sensitive. Change to `policy-group-members` in the blueprint if kids should have their own accounts too.

### The cross-host outpost routing problem

Authentik's "forward auth (single application)" mode requires `<external_host>/outpost.goauthentik.io/*` — on the **app's own domain** — to be routed to the outpost that actually handles the login callback/session-cookie exchange for that domain. Authentik (and its embedded outpost) runs on **Hearth** (Docker Compose); Firefly runs on **Forge** (k3s) — a different host. To bridge this, the chart adds:

- `templates/service-outpost.yaml` — a plain Kubernetes `ExternalName` Service pointing at `auth.huybrechts.xyz` (with `traefik.ingress.kubernetes.io/service.serversscheme: https` so Traefik connects out over HTTPS).
- `templates/ingress-outpost.yaml` — a second Ingress on the same `finance.huybrechts.xyz` host, routing the `/outpost.goauthentik.io` path prefix to that ExternalName Service, with **no** forwardAuth middleware attached (it must stay reachable unauthenticated, or the login flow would loop).

Traefik gives more-specific path prefixes higher route priority automatically, so this outpost path always wins over the app's catch-all `/` — no explicit priority annotation should be needed, but confirm this with `kubectl describe ingressroute`/Traefik's dashboard if login redirects loop.

### Open risks / not yet live-verified

This whole SSO integration is **unverified** — it has no precedent elsewhere in this repo (every other app is same-origin OIDC). Expect to iterate after the first real deploy + login attempt:

- Whether `remote_user_guard` really matches on the exact header/value set here (`X-Authentik-Email`) the way assumed — Firefly's own docs on this are thin; may need adjusting the header name or adding `AUTHENTICATION_GUARD_EMAIL` too.
- Whether the cross-host outpost bypass (`ExternalName` Service → `auth.huybrechts.xyz` over HTTPS) actually completes the login callback correctly — this pattern has never been used anywhere else in this repo.
- `remote_user_guard` does **not** create Firefly users — a Firefly account (matching the family member's Authentik email) must be created once via Firefly's own registration screen *before* switching this on, same one-time-bootstrap precedent as Jellyfin/Immich's admin setup. Consider deploying with `AUTHENTICATION_GUARD=web` first to create the accounts, then switching to `remote_user_guard`.
- Authentik's default behavior (the "authentik Embedded Outpost" auto-manages any Proxy provider not assigned elsewhere) is assumed, not confirmed against this specific Authentik version.

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
