# Homarr

> Homarr — family-facing dashboard/landing page linking to every deployed haven service. Real per-user boards, groups and permissions synced from Authentik — unlike Authentik's own application launcher (admin-managed only, shared for everyone), each Homarr user can customize their own board and icons.

## Overview

Homarr runs on **Forge** (Hetzner CPX41, k3s) in the `system` Kubernetes namespace, alongside cert-manager and Gatus. It's a single landing page that links out to every family-facing app (Immich, Jellyfin, Nextcloud, Kavita, Vaultwarden, etc.), with widgets, search, and a drag-and-drop layout editor.

This was promoted from [future.md](../future.md)'s wishlist after a design discussion (see the design rationale below for why Homarr was chosen over the alternative, Homepage).

**Prerequisites:**
- `deploy-forge-init.yml` must have run successfully (k3s + Traefik installed).
- DNS A record for `home.{domain}` must point at Forge's public IP (Forge terminates its own ingress).
- The `system` namespace and cert-manager must already be deployed (Homarr's ingress depends on their `letsencrypt-staging`/`letsencrypt-prod` `ClusterIssuer`s).

---

## Why Homarr, not Homepage

Both were real, actively maintained candidates from `future.md`. Decision:

|                        | Homepage (`gethomepage/homepage`)                                            | **Homarr (`homarr-labs/homarr`)**                                                          |
| ---------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Config model           | Static YAML files, one shared config for everyone                            | Drag-and-drop UI, DB-backed, no YAML required                                              |
| Per-user customization | ❌ everyone behind the login sees the same page                               | ✅ real user accounts, groups, permissions, own boards                                      |
| Icons                  | Shared icon set, admin-edited YAML                                           | ✅ built-in picker (11k+ icons), user-editable                                              |
| Auth                   | Optional OIDC login or simple password (just an "authenticated or not" gate) | ✅ native OIDC **and** LDAP, designed for real multi-user auth with group-based permissions |
| Kubernetes/Helm        | Community `kubernetes.md` guide, no first-class Helm chart                   | ✅ official chart (`homarr-labs/charts`), explicitly advertised Kubernetes support          |

Homepage would just be another centrally-maintained YAML file (like the Authentik application-tile blueprint) — Homarr is the one that actually answers "can users customize their own icons/layout": yes, because it has real per-user boards, not a single shared config.

---

## What gets deployed

| Item      | Value                                                                                                                                                                      |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chart     | `homarr` from `oci://ghcr.io/homarr-labs/charts` (official, OCI — maintainers' recommended install path)                                                                   |
| Version   | `2.4.0` (pinned)                                                                                                                                                           |
| Namespace | `system` (shared with cert-manager and Gatus, not isolated)                                                                                                                |
| Modules   | `config/forge/modules/homarr-secrets.yaml` (K8s Secrets), `config/forge/modules/homarr.yaml` (app)                                                                         |
| Ingress   | Traefik (`className: traefik`), host `home.{domain}`, TLS via cert-manager (`letsencrypt-staging` first, same staging-then-prod rollout as every other app's first deploy) |
| Database  | sqlite (`better-sqlite3`, the chart's default), persisted to a 200Mi PVC — no mysql subchart needed at this scale                                                          |

---

## Secrets

| Secret                     | Store     | Used by                                                                                                                                                                                                                                    |
| -------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `HOMARR_SSO_CLIENT_SECRET` | Infisical | Routed through `homarr-secrets.yaml`'s K8s Secret (`homarr-auth-oidc-secret`, key `oidc-client-secret`) — the chart reads OIDC credentials via `envSecrets`, not a plain `env:` var                                                        |
| `HOMARR_DB_ENCRYPTION_KEY` | Infisical | Routed through `homarr-secrets.yaml`'s K8s Secret (`homarr-db-secret`, key `db-encryption-key`) — Homarr's `SECRET_ENCRYPTION_KEY`, encrypts integration credentials Homarr stores in its own database. Required regardless of DB backend. |

### Why a separate `homarr-secrets` module

The official Homarr chart routes its two credential fields (OIDC client secret, DB encryption key) through `envSecrets.*.existingSecret` — a **referenced** Kubernetes Secret name + key, never a literal `env:` value. strata's Helm secret substitution only resolves `${TOKEN}` placeholders found inside a dict node keyed literally `env` — so these two fields aren't directly reachable from `homarr.yaml`.

Same fix pattern as `nextcloud-secrets`/`rclone-mount` earlier in this repo: a small local chart (`services/forge/homarr-secrets`) whose own values ARE `env:`-shaped (so strata substitutes them correctly), rendering nothing but two `kind: Secret` objects. `homarr.yaml` then points at them via `envSecrets.authOidcCredentials.existingSecret` / `envSecrets.dbCredentials.existingSecret` — using the chart's own default Secret/key names (`homarr-auth-oidc-secret`/`homarr-db-secret`, `oidc-client-id`/`oidc-client-secret`/`db-encryption-key`) so no extra overrides are needed beyond pointing at the right Secret name.

---

## Single Sign-On (Authentik) and per-user permissions

Homarr is built on Auth.js/NextAuth and has **native OIDC support** — no plugin or forward-auth proxy needed.

The Authentik side is **already automated** — `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Homarr (client ID `homarr`, `members` group policy, `mapping-group-membership` scope mapping for the `groups` claim) every time `deploy-hearth-config.yml` runs, using the `HOMARR_SSO_CLIENT_SECRET` Infisical secret.

```yaml
AUTH_PROVIDERS: "oidc,credentials"   # credentials kept as a bootstrap fallback for now
AUTH_OIDC_ISSUER: "https://auth.huybrechts.xyz/application/o/homarr/"  # trailing slash kept — Homarr's own docs call out Authentik as the one exception
AUTH_OIDC_CLIENT_NAME: "Authentik"
AUTH_OIDC_SCOPE_OVERWRITE: "openid email profile groups"
AUTH_OIDC_GROUPS_ATTRIBUTE: "groups"
```

**This is what makes per-user customization actually work.** Per Homarr's own documented Authentik example: a user is automatically placed into any *locally-created Homarr group* that shares the same **name** as an Authentik group in the `groups` claim. Since the blueprint already defines `admins`/`parents`/`members` groups, the one remaining manual step is:

1. Log in to Homarr as the bootstrap admin (via the `credentials` provider, first-run onboarding).
2. Create three groups in Homarr's own admin UI, named exactly `admins`, `parents`, `members`.
3. Assign the permissions/board access you want to each group (e.g. `admins` gets an extra "Infra" board with links to Terraform Cloud/Infisical/Hetzner Console — mirroring the admin-only tiles already in Authentik itself, see below).

From then on, every OIDC login auto-syncs group membership from Authentik — no per-user manual account creation, and each user can still personalize their **own** board layout/icons within whatever their group permits.

**Redirect URI:** `https://home.huybrechts.xyz/api/auth/callback/oidc` (fixed Auth.js/NextAuth convention for a generic OIDC provider, confirmed via Homarr's own docs' worked Authentik example — not app-specific/configurable).

**Logout:** `AUTH_LOGOUT_REDIRECT_URL` points at Authentik's end-session endpoint (`.../application/o/homarr/end-session/`) for a clean SSO logout, not just a local Homarr session clear.

### Rollout caution (mirrors every other app's first deploy)

- `AUTH_PROVIDERS` is `"oidc,credentials"`, not `"oidc"` alone — keeps local username/password login available so the first-run onboarding wizard (which creates the bootstrap admin) still works. Tighten to `"oidc"` only once OIDC + group sync are confirmed working live.
- `AUTH_OIDC_AUTO_LOGIN` is `"false"` (manual login button) until then — flip to `"true"` afterwards for the one-click landing-page feel.
- Ingress uses `letsencrypt-staging` first — flip to `letsencrypt-prod` once the HTTP-01 challenge for `home.huybrechts.xyz` has succeeded once (same pattern as every other Forge app's first deploy).

---

## Relationship to the admin-only Authentik bootstrap links

Earlier, admin-only dashboard tiles (Terraform Cloud, Infisical Cloud, Hetzner Cloud Console, the strata/haven GitHub repos) were added directly to Authentik's own application launcher, gated by `policy-group-admins` (see `authentik-blueprint.yaml.j2`). Those still exist and still work — Homarr doesn't replace them.

The difference: Authentik's launcher is **admin-managed and shared** (every admin sees the same tiles, defined in the blueprint). Homarr's `admins`-group board can additionally surface the *same* links in a nicer/organized layout **that each admin can further rearrange for themselves** — Homarr is the place for personalization, Authentik's launcher remains the source of truth for "what admin tools exist."

---

## Storage

| Volume                | Type                     | Notes                                                                |
| --------------------- | ------------------------ | -------------------------------------------------------------------- |
| `homarr-database` PVC | PVC, `local-path`, 200Mi | sqlite database — persists boards/users/settings across pod restarts |

Without this PVC, Homarr defaults to ephemeral pod-disk storage (all boards/settings lost on every restart) — same reasoning as Gatus's `persistence.data` volume.

---

## Verification checklist

- [ ] `https://home.{domain}` — Homarr loads and is reachable from a browser
- [ ] First-run onboarding creates a bootstrap admin via the credentials provider
- [ ] "Sign in with Authentik" OIDC button appears alongside the credentials login form
- [ ] `admins`/`parents`/`members` groups created in Homarr's own admin UI, matching Authentik's group names exactly
- [ ] A `members` group user can sign in via OIDC and lands in the correct Homarr group
- [ ] Each user can drag-and-drop rearrange their own board and change icons without affecting other users

---

## Architecture notes

### Shared `system` namespace

Like Gatus, Homarr shares the `system` namespace with cert-manager rather than getting its own namespace — it's a cross-cutting dashboard, not a tenant-isolated application with its own data model tied to one app layer.

### Why `homarr-secrets` runs first

`config/forge/namespaces/system.yaml` lists `homarr-secrets` immediately before `homarr` — the K8s Secrets it renders must exist before `homarr.yaml`'s `envSecrets.*.existingSecret` references resolve, same ordering reason as `nextcloud-secrets` before `nextcloud`.

---

## Still open

- Homarr's own `admins`/`parents`/`members` groups and their permission assignments are a one-time manual step (no blueprint-equivalent for Homarr itself) — not yet performed, pending first deploy.
- Widgets/integrations (e.g. live status cards for Immich/Jellyfin/Nextcloud, matching what Gatus already health-checks) are not yet configured — Homarr supports 40+ service widgets natively, this is a nice-to-have once the base dashboard is confirmed working.
- `AUTH_PROVIDERS`/`AUTH_OIDC_AUTO_LOGIN` tightening (see Rollout caution above) — deferred until OIDC + group sync are confirmed live.
