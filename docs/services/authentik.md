# Authentik Setup for Haven

## Overview

Authentik is the identity provider for Haven. It provides SSO (OIDC) for family-facing services and is configured **declaratively** — all providers, applications, groups, and policies are managed through an Authentik Blueprint applied by the configuration pipeline.

This document covers:
- How the blueprint mechanism works and how to run it
- The general SSO-wiring pattern for adding a new application
- The group/policy access model
- The authentication strategy (which services use SSO vs. local auth)
- A per-app SSO index (full details live in each service's own doc)

---

## Deployment flow

Authentik setup is two-phase:

1. **Deploy** — `deploy-hearth-deploy.yml` brings up the Authentik containers via Docker Compose on the Hearth VM.
2. **Configure** — `deploy-hearth-config.yml` renders `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` with secrets from Infisical (via strata) and copies the rendered file to `/opt/haven/etc/authentik/blueprints/haven-apps.yaml` on the server.

The Authentik worker auto-applies blueprints from `/blueprints/custom/` on startup. Re-running the config pipeline updates existing resources in place — it is idempotent.

---

## One-time prerequisites

### Rename the default brand (first deploy only)

Before the first blueprint apply, rename the default brand's domain in the Authentik admin UI:

> Admin Interface → System → Brands → edit `authentik-default` → set Domain to `auth.huybrechts.xyz` → Save

The blueprint thereafter manages the brand automatically.

### Create users and assign groups

The blueprint creates groups and policies automatically. User accounts are **not** automated — create them manually after the first deploy:

1. Admin Interface → Directory → Users → Create
2. For each family member: username (lowercase first name), full name, `<name>@huybrechts.xyz`

Then assign each user to a group:

| User / role            | Group     | Access                         |
| ---------------------- | --------- | ------------------------------ |
| Tech admin (`akadmin`) | `admins`  | All apps                       |
| Adult family members   | `parents` | All family apps                |
| Other family members   | `members` | Shared apps (e.g. Vaultwarden) |

1. Admin Interface → Directory → Groups → select group → Users tab → Add existing user

> ⚠️ Until a user is in at least one group, SSO logins will fail with **"Policy binding returned result False"** — the user is authenticated but not authorised.

---

## Group and policy model

The blueprint creates three groups and a corresponding group-membership policy for each:

| Group     | Policy                 | Who belongs           |
| --------- | ---------------------- | --------------------- |
| `admins`  | `policy-group-admins`  | Tech admin            |
| `parents` | `policy-group-parents` | Adult family members  |
| `members` | `policy-group-members` | Everyone (kids, etc.) |

Application access is gated by binding the appropriate policy to each application:

| Application | Bound policy           | Who can log in        |
| ----------- | ---------------------- | --------------------- |
| Vaultwarden | `policy-group-members` | Everyone (all groups) |
| WUD         | `policy-group-admins`  | Admins only           |
| Immich      | `policy-group-members` | Everyone (all groups) |
| Jellyfin    | `policy-group-members` | Everyone (all groups) |
| Nextcloud   | `policy-group-members` | Everyone (all groups) |

---

## MFA

MFA is configured by the blueprint — the `default-authentication-mfa-validation` stage is bound to `default-authentication-flow` at order `30` (after password at `20`).

The behaviour when a user has no MFA device configured is set by `authentik_mfa_not_configured_action` in `deploy/ansible-hearth/vars/main.yml`:

| Value       | Behaviour                                      |
| ----------- | ---------------------------------------------- |
| `configure` | Redirect user to enroll MFA at login (default) |
| `deny`      | Block login until an admin configures MFA      |
| `skip`      | Allow login without MFA (not recommended)      |

Verify after deploy: Admin Interface → Flows & Stages → Flows → `default-authentication-flow` → Stage Bindings → should show `10` identification → `20` password → `30` mfa-validation.

---

## Authentication strategy

Not all services use Authentik SSO. SSO creates a dependency — if Authentik is down, SSO-protected services become inaccessible. The rule is:

| Service         | Auth method                  | Reason                                                                    |
| --------------- | ---------------------------- | ------------------------------------------------------------------------- |
| **Vaultwarden** | Authentik SSO (OIDC)         | Family-facing — ease of access for all users                              |
| **WUD**         | Authentik SSO (OIDC)         | Admin tool, already working and low-friction                              |
| **Immich**      | Authentik SSO (OIDC)         | Family photo library — family members need access                         |
| **Jellyfin**    | Authentik SSO (OIDC, plugin) | Family media — family members need access                                 |
| **Nextcloud**   | Authentik SSO (OIDC)         | Family file sync — family members need access                             |
| **Kavita**      | Authentik SSO (OIDC, native) | Family document/TTRPG library — now wired up alongside Nextcloud/Jellyfin |
| **Portainer**   | Local credentials + TOTP MFA | Admin tool — must stay accessible if Authentik is down                    |

> ⚠️ **Do not configure SSO for Portainer.** If Authentik fails, Portainer is your recovery tool.

---

## Per-app SSO index

Full SSO configuration details live in each service's own doc. This table summarises the integration approach.

| App         | `issuer_mode`  | Auth method        | Secret in Infisical             | Doc                              |
| ----------- | -------------- | ------------------ | ------------------------------- | -------------------------------- |
| Vaultwarden | `per_provider` | OIDC               | `VAULTWARDEN_SSO_CLIENT_SECRET` | [vaultwarden.md](vaultwarden.md) |
| WUD         | `global`       | OIDC               | `WUD_SSO_CLIENT_SECRET`         | [wud.md](wud.md)                 |
| Immich      | `per_provider` | OIDC (native)      | `IMMICH_OAUTH_CLIENT_SECRET`    | [immich.md](immich.md)           |
| Jellyfin    | `per_provider` | OIDC (plugin)      | `JELLYFIN_SSO_CLIENT_SECRET`    | [jellyfin.md](jellyfin.md)       |
| Nextcloud   | `per_provider` | OIDC (`user_oidc`) | `NEXTCLOUD_SSO_CLIENT_SECRET`   | [nextcloud.md](nextcloud.md)     |
| Kavita      | `per_provider` | OIDC (native)      | `KAVITA_SSO_CLIENT_SECRET`      | [kavita.md](kavita.md)           |

**`issuer_mode` guidance:**
- Use `per_provider` for every app. Authentik does not expose a global `/.well-known/openid-configuration` endpoint; per-app discovery URLs (`https://auth.huybrechts.xyz/application/o/<slug>/`) always work.
- WUD uses `global` and is confirmed working — do not change it. Every other app uses `per_provider`.

---

## Adding a new SSO application (general pattern)

Four steps to wire an additional app into the blueprint:

### Step 1 — Declare the secret

Add the client secret to `config/environment.yaml` under the `secrets:` block:

```yaml
- name: MYAPP_SSO_CLIENT_SECRET
  infisical:
    generate:
      length: 48
      type: urlsafe
```

Run `strata validate` then `strata deploy --secrets` to generate and push the secret to Infisical.

### Step 2 — Add the blueprint block

In `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2`, add:

- A **provider** entry (OAuth2/OIDC, `issuer_mode: per_provider`, redirect URI, `signing_key`, `client_id`, `client_secret: {{ myapp_sso_client_secret }}`)
- An **application** entry referencing the provider
- A **policy binding** entry linking the appropriate group policy to the application

Follow the existing `Vaultwarden` provider/application/binding blocks as a template.

### Step 3 — Wire the secret into the config pipeline

In `deploy/ansible-hearth/vars/main.yml`, expose the secret as a template variable:

```yaml
myapp_sso_client_secret: "{{ lookup('env', 'MYAPP_SSO_CLIENT_SECRET') }}"
```

The `deploy-hearth-config.yml` workflow passes secrets from Infisical as environment variables; `lookup('env', ...)` picks them up.

### Step 4 — Configure the app side

Register the client ID and secret on the application's side. This step varies by application — see the individual service doc for the exact configuration.

---

## About the blueprint

### What the blueprint manages

| Area           | Resources                                                             | Purpose                                                     |
| -------------- | --------------------------------------------------------------------- | ----------------------------------------------------------- |
| Branding       | `authentik-default` brand for `auth.huybrechts.xyz`                   | Haven-branded login page                                    |
| MFA            | `default-authentication-mfa-validation` stage + flow binding          | Enforces MFA enrollment                                     |
| Groups         | `admins`, `parents`, `members`                                        | Family access model                                         |
| Policies       | `policy-group-admins`, `policy-group-parents`, `policy-group-members` | Per-group application gating                                |
| Scope mapping  | `haven-email-verified`                                                | Forces `email_verified: true` for manually created accounts |
| OIDC providers | One per SSO-enabled app                                               | Authentik acts as IdP for each app                          |
| Applications   | One per SSO-enabled app                                               | Launchable entries in the Authentik portal                  |

### Blueprint location

- Template: `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2`
- Config playbook: `deploy/ansible-hearth/hearth-config.yml`
- Rendered output on server: `/opt/haven/etc/authentik/blueprints/haven-apps.yaml`
- Authentik mount: `/blueprints/custom/` (shared between server and worker containers)

### Secrets

All client secrets are stored in **Infisical** and injected at pipeline runtime via strata. They are declared in `config/environment.yaml`. No secrets are stored in GitHub; secrets declared with `generate:` are auto-generated by strata on first deploy.

### Verifying the blueprint applied

After running the config pipeline:

- Admin Interface → Applications → Providers — check all configured providers are present
- Admin Interface → Applications → Applications — check all apps are listed
- Admin Interface → Directory → Groups — check `admins`, `parents`, `members` exist
- Admin Interface → System → Brands — `auth.huybrechts.xyz` with title `Haven`
- Admin Interface → System → Tasks — check for any blueprint apply errors
