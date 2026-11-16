# Gatus

> Gatus — live health/status dashboard for all family services, members-only access via Authentik OIDC.

## Overview

Gatus runs on **Forge** (Hetzner CPX41, k3s) in the `system` Kubernetes namespace, alongside cert-manager. It provides a real-time health dashboard aggregating status checks for all deployed services (Authentik, Vaultwarden, WUD, Portainer on Hearth; Immich, Jellyfin, Nextcloud, Kavita on Forge).

**Prerequisites:**
- `deploy-forge-init.yml` must have run successfully (k3s + Traefik installed).
- DNS A record for `status.{domain}` must point at Forge's public IP (Forge terminates its own ingress).
- The `system` namespace and cert-manager must already be deployed (Gatus ingress depends on their `letsencrypt-staging`/`letsencrypt-prod` `ClusterIssuer`s).

---

## What gets deployed

| Item      | Value                                                                                             |
| --------- | ------------------------------------------------------------------------------------------------- |
| Chart     | `gatus` from the official repo, `https://twin.github.io/helm-charts`                              |
| Version   | `1.0.0` (pinned)                                                                                  |
| Namespace | `system` (shared with cert-manager, not isolated)                                                 |
| Module    | `config/forge/modules/gatus.yaml`                                                                 |
| Ingress   | Traefik (`className: traefik`), host `status.{domain}`, TLS via cert-manager (`letsencrypt-prod`) |

---

## Secrets

| Secret                       | Store     | Used by                                                          |
| ---------------------------- | --------- | ---------------------------------------------------------------- |
| `GATUS_SSO_CLIENT_SECRET`    | Infisical | Pod env var `GATUS_OIDC_CLIENT_SECRET` (Authentik OAuth2 secret) |
| `INFOMANIAK_EMAIL__HOST`     | Infisical | Pod env var `GATUS_SMTP_HOST` (email alerting SMTP host)         |
| `INFOMANIAK_EMAIL__PORT`     | Infisical | Pod env var `GATUS_SMTP_PORT` (email alerting SMTP port)         |
| `INFOMANIAK_EMAIL__USERNAME` | Infisical | Pod env var `GATUS_SMTP_USERNAME` (email alerting SMTP auth)     |
| `INFOMANIAK_EMAIL__PASSWORD` | Infisical | Pod env var `GATUS_SMTP_PASSWORD` (email alerting SMTP auth)     |

---

## Initial setup

### Single Sign-On (Authentik)

Gatus has **native OIDC support** — no plugin or forward-auth proxy needed.

The Authentik side is **already automated** — `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Gatus (client ID `gatus`, `members` group policy) every time `deploy-hearth-config.yml` runs, using the `GATUS_SSO_CLIENT_SECRET` Infisical secret.

The Gatus side is **fully automated** — the Helm chart's `spec.configuration.config.security.oidc` section is populated at deploy time via strata's secret substitution (`${GATUS_SSO_CLIENT_SECRET}`), injected into the pod's environment, and read by Gatus at startup:

```yaml
security:
  oidc:
    issuer-url: https://auth.huybrechts.xyz/application/o/gatus/
    redirect-url: https://status.huybrechts.xyz/authorization-code/callback
    client-id: gatus
    client-secret: "${GATUS_OIDC_CLIENT_SECRET}"  # Gatus's own env-var substitution
    scopes: ["openid", "email", "profile"]
```

**Access control:** Authentik's policy-group-members binding (enforced on the Gatus Application in the blueprint) restricts real login access to members of the `members` group — only authenticated `members` group users can log in. Dashboard visibility is not the security boundary; the OIDC auth itself is.

---

### Email alerting (fully automated)

Gatus's built-in `alerting.email` provider is configured — sends an email to `admin@huybrechts.xyz` whenever any monitored endpoint fails 3 consecutive checks, and a resolved notification once it recovers (`send-on-resolved: true`). Every endpoint in the config has `alerts: [{type: email}]` attached.

Reuses the same shared Infomaniak mailbox as Vaultwarden/Authentik — no separate mailbox or app password needed. Same double-substitution pattern as the OIDC client secret above: strata resolves `${INFOMANIAK_EMAIL__*}` into real pod env vars (`GATUS_SMTP_*`) at deploy time, and Gatus's own runtime env-var substitution reads those in `config.alerting.email`:

```yaml
alerting:
  email:
    from: gatus@huybrechts.xyz
    host: "${GATUS_SMTP_HOST}"
    port: ${GATUS_SMTP_PORT}
    username: "${GATUS_SMTP_USERNAME}"
    password: "${GATUS_SMTP_PASSWORD}"
    to: "admin@huybrechts.xyz"
```

No manual step required — this takes effect on the next `deploy-forge-deploy.yml` run. To change the recipient, edit the `to:` value in `config/forge/modules/gatus.yaml`.

---

## Health endpoints

The config includes reachability checks (HTTP 200) for every deployed service, grouped by node for the dashboard view:

| Service     | Endpoint                           | Group  | Interval |
| ----------- | ---------------------------------- | ------ | -------- |
| Authentik   | `https://auth.huybrechts.xyz`      | hearth | 60s      |
| Vaultwarden | `https://vault.huybrechts.xyz`     | hearth | 60s      |
| WUD         | `https://wud.huybrechts.xyz`       | hearth | 5m       |
| Portainer   | `https://portainer.huybrechts.xyz` | hearth | 5m       |
| Immich      | `https://photos.huybrechts.xyz`    | forge  | 60s      |
| Jellyfin    | `https://media.huybrechts.xyz`     | forge  | 60s      |
| Nextcloud   | `https://docs.huybrechts.xyz`      | forge  | 60s      |
| Kavita      | `https://books.huybrechts.xyz`     | forge  | 5m       |

Add or remove endpoints by editing `config/forge/modules/gatus.yaml`'s `spec.configuration.config.endpoints` list, then redeploy via `33 - Forge - Deploy`.

---

## Storage

| Volume             | Type                     | Notes                                                    |
| ------------------ | ------------------------ | -------------------------------------------------------- |
| `persistence.data` | PVC, `local-path`, 200Mi | SQLite database (`data.db`) for historical uptime/status |

The small 200Mi PVC persists the SQLite database across pod restarts — without this, Gatus defaults to in-memory storage (lost on every pod restart).

---

## Verification checklist

- [ ] `https://status.{domain}` — Gatus loads and is reachable from a browser
- [ ] OIDC "Sign in with Authentik" button appears on login page
- [ ] A `members` group user can sign in and see the dashboard
- [ ] All configured endpoints show as healthy (green HTTP 200 indicators)

---

## Architecture notes

### Shared `system` namespace

Unlike Immich, Jellyfin, etc., which each get their own namespace, Gatus shares the `system` namespace with cert-manager. This is intentional — Gatus is a cluster-wide monitoring tool, not a tenant-isolated application. No collision risk because cert-manager exports only a few CRDs/webhooks; Gatus is a single stateless pod (plus its PVC).

### Native OIDC vs. forward-auth

Gatus's own OIDC support means the login flow is:
1. User hits `https://status.huybrechts.xyz`
2. Unauthenticated → Gatus redirects to `issuer-url` (Authentik)
3. Authentik challenges, validates group membership, redirects back to `redirect-url`
4. Gatus sets a session cookie and grants access

This is cleaner than a reverse proxy with a forward-auth middleware, and the access control is enforced at the OIDC boundary (Authentik's policy), not by dashboard-level visibility tricks.

---

## Still open

- Endpoint alerting (Slack/email/webhook notifications on status change) — not yet configured; see Gatus's [alerting docs](https://gatus.io/configuration/alerting/) for options
