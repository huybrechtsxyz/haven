# Authentik Setup for Haven

[Back to Guide](./GUIDE.md#setup-authentik)

## Overview

This guide covers the setup and configuration of Authentik, the identity provider for the Haven system. Authentik provides centralized authentication and authorization for all services in the stack.

## Service Setup

Authentik is configured and deployed in the configurator and deployer playbooks, respectively. After deployment, you need to create user accounts and assign them to groups in the Authentik admin interface to enable SSO access to Vaultwarden and WUD.

The setup is a three-step process:

1. Deploy the Authentik containers using the hearth deploy workflow.
2. Configure Authentik resources (groups, policies, OIDC providers) using the blueprint rendered by the config workflow.
3. Manually create user accounts and assign them to groups in the Authentik admin interface.

## Branding Authentik

Branding is configured automatically by the blueprint — the `authentik-default` brand domain is updated to `auth.huybrechts.xyz` with title `Haven`.

> ⚠️ One-time prerequisite: rename the existing default brand's domain from `*` to `auth.huybrechts.xyz` in the UI before the first blueprint apply: Admin Interface → System → Brands → edit `authentik-default` → set Domain to `auth.huybrechts.xyz` → Save.

## Assign users to groups

The blueprint creates three groups automatically (`admins`, `parents`, `members`) and all SSO applications are gated by group policy. **No user can log in to any SSO application until they are assigned to at least one group.** This includes `akadmin`.

Assign group membership after every new user is created:

| User                              | Group     | Access          |
| --------------------------------- | --------- | --------------- |
| `akadmin` (or your admin account) | `admins`  | All apps        |
| Adult family members              | `parents` | All family apps |
| Other family members              | `members` | Shared apps     |

**Steps:**

1. Admin Interface → Directory → Groups → select the group
2. Users tab → Add existing user → select the user → Add
3. Repeat for each user

> ⚠️ If this step is skipped, SSO logins will fail with **"Permission denied — Policy binding returned result False"**. The user is authenticated but not authorised.

### Add users

1. Admin Interface → Directory → Users → Create
2. For each family member:
   - Username: first name (lowercase)
   - Name: full name
   - Email: `<name>@huybrechts.xyz`
3. Set initial password or send enrollment email (requires SMTP)

### Assign groups

Groups are created automatically by the blueprint. After creating users, assign them:

| Group     | Members               | App access                             |
| --------- | --------------------- | -------------------------------------- |
| `admins`  | You (tech admin)      | All applications                       |
| `parents` | Parents               | All family applications                |
| `members` | Everyone (kids, etc.) | Shared applications (e.g. Vaultwarden) |

1. Admin Interface → Directory → Users → select user → Groups tab → Add to group

### Enforce MFA (recommended)

MFA is configured automatically by the blueprint — the `default-authentication-mfa-validation` stage is bound to the login flow at order `30` (after password at `20`) and `not_configured_action` is set to `configure`.

After deploy, verify: Admin Interface → Flows & Stages → Flows → `default-authentication-flow` → Stage Bindings tab should show `10` identification → `20` password → `30` mfa-validation.
Also verify: Flows & Stages → Stages → `default-authentication-mfa-validation` shows Not configured action = `Configure`.

Users without MFA configured will be prompted to enroll an authenticator on their next login instead of bypassing MFA.

## Authentication strategy

**Not all services use Authentik SSO.** SSO adds complexity and creates a single point of failure — if Authentik is down, SSO-protected services become inaccessible. The strategy is:

| Service         | Auth method                  | Reason                                                 |
| --------------- | ---------------------------- | ------------------------------------------------------ |
| **Vaultwarden** | Authentik SSO                | Family-facing — ease of access for all users           |
| **WUD**         | Authentik SSO                | Admin tool, but already working and low-friction       |
| **Portainer**   | Local credentials + TOTP MFA | Admin tool — must stay accessible if Authentik is down |
| **Infisical**   | Local credentials + TOTP MFA | Admin tool — must stay accessible if Authentik is down |

> ⚠️ **Do not configure SSO for Portainer or Infisical.** If Authentik fails, you need these tools to diagnose and fix the problem. Keep them on independent local auth.

## About the blueprint

### Automated Setup

Authentik setup is split into two parts:

- The Authentik containers are deployed by the hearth deploy workflow.
- The SSO configuration inside Authentik is rendered from a blueprint template and applied automatically by the config workflow.

- **Blueprint:** `deploy/ansible-config/templates/authentik-blueprint.yaml.j2`
- **Config playbook:** `deploy/ansible-config/hearth-config.yml`

### Blueprint Overview

The blueprint is an idempotent Authentik resource definition. Ansible renders it with the client secrets from GitHub Environment Secrets and places the result on the server, where the Authentik worker imports it from `/blueprints/custom/` on startup.

Re-running the config pipeline updates existing Authentik resources in place instead of recreating them.

### What the blueprint creates

The blueprint manages the following Authentik resources for Haven:

| Area          | Resources created or updated                                                                                    | Purpose                                                             |
| ------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| MFA           | `default-authentication-mfa-validation` stage and a flow binding on `default-authentication-flow` at order `30` | Forces MFA enrollment for users without an authenticator configured |
| Groups        | `admins`, `parents`, `members`                                                                                  | Defines the family access model                                     |
| Policies      | `policy-group-admins`, `policy-group-parents`, `policy-group-members`                                           | Restricts application access by group membership                    |
| Scope mapping | `haven-email-verified`                                                                                          | Forces `email_verified: true` for trusted internal users            |
| OIDC provider | `Vaultwarden`                                                                                                   | Configures Authentik as the OIDC provider for Vaultwarden           |
| OIDC provider | `WUD`                                                                                                           | Configures Authentik as the OIDC provider for What's Up Docker      |
| Applications  | `vaultwarden`, `wud`                                                                                            | Creates launchable applications in the Authentik portal             |
| Branding      | Brand for `auth.huybrechts.xyz` with title `Haven`                                                              | Applies Haven branding to the Authentik login experience            |

### Access model

The blueprint encodes the intended access rules for Haven:

| Group     | Access                                                 |
| --------- | ------------------------------------------------------ |
| `admins`  | All applications, including WUD                        |
| `parents` | Family applications through the `members` policy chain |
| `members` | Shared family applications such as Vaultwarden         |

Application bindings currently resolve to:

| Application | Access policy          |
| ----------- | ---------------------- |
| Vaultwarden | `policy-group-members` |
| WUD         | `policy-group-admins`  |

### OIDC details

The rendered blueprint configures two confidential OAuth2/OIDC providers:

- `vaultwarden` with redirect URI `https://vault.huybrechts.xyz/identity/connect/oidc-signin`
- `wud` with redirect URI `https://wud.huybrechts.xyz/auth/oidc/authentik/cb`

For Vaultwarden, the blueprint also adds a custom scope mapping that forces `email_verified` to `true`. This is needed because Vaultwarden rejects logins when Authentik users were created manually and their email is not marked as verified.

### Deployment flow

The blueprint is applied as part of the configuration phase:

1. GitHub Actions runs the `deploy.yml` workflow with `run_config: true`.
2. The workflow passes `vaultwarden_sso_client_secret` and `wud_sso_client_secret` to `deploy/ansible-config/hearth-config.yml`.
3. Ansible renders `authentik-blueprint.yaml.j2` and places it in the mounted Authentik blueprint directory on the server.
4. The Authentik worker imports the blueprint and creates or updates the configured resources.

### Manual steps that still remain

The blueprint does not create family user accounts. After deployment, you still need to:

1. Create users in the Authentik admin interface.
2. Assign users to the `admins`, `parents`, or `members` groups.
3. Verify that the default authentication flow includes the MFA validation stage.

Once those steps are complete, Vaultwarden and WUD authentication is managed by the blueprint and kept in sync by the config pipeline.

## OIDC Applications: Vaultwarden & WUD

All SSO applications are configured automatically via an **Authentik Blueprint** — no manual UI steps for providers or applications.

### How it works

1. Client secrets are pre-generated and stored as GitHub Secrets
2. The config pipeline renders `authentik-blueprint.yaml.j2` (with secrets substituted) and copies it to `/opt/haven/etc/authentik/blueprints/haven-apps.yaml` on the server
3. That directory is mounted into both the Authentik server and worker containers at `/blueprints/custom/`
4. Authentik worker auto-applies the blueprint on startup — creating/updating providers, applications, groups, policies, and branding idempotently

### Access control

| Application | Access group | Who can log in        |
| ----------- | ------------ | --------------------- |
| Vaultwarden | `members`    | Everyone (all groups) |
| WUD         | `admins`     | Admins only           |

### Prerequisites (one-time)

Generate two client secrets and add them to the `production` GitHub Environment Secrets:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

| Secret                          | Notes                   |
| ------------------------------- | ----------------------- |
| `VAULTWARDEN_SSO_CLIENT_SECRET` | One generated value     |
| `WUD_SSO_CLIENT_SECRET`         | Another generated value |

### Deploy

Run the pipeline with `run_config: true` + `run_deploy: true`. After Authentik restarts, verify in the admin UI:

- Admin Interface → Applications → Providers — should show `Vaultwarden` and `WUD`
- Admin Interface → Applications → Applications — should show both apps
- Admin Interface → Directory → Groups — should show `admins`, `parents`, `members`
- Admin Interface → System → Brands — `auth.huybrechts.xyz` should have title `Haven`

> If providers are missing, check: Admin Interface → System → Tasks — look for blueprint apply errors.

### Vaultwarden SSO env vars

Vaultwarden reads SSO config from environment variables set in `config/hearth/modules/mod-vaultwarden.yaml`. No additional configuration needed — `SSO_AUTHORITY`, `SSO_CLIENT_ID`, and `SSO_CLIENT_SECRET` are already wired.

**Critical configuration notes** (hard-won — do not change these):

| Setting                        | Value                                                    | Why                                                                                                        |
| ------------------------------ | -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `SSO_AUTHORITY`                | `https://auth.huybrechts.xyz/application/o/vaultwarden/` | Per-app discovery URL — Authentik has **no** global `/.well-known/openid-configuration` endpoint           |
| `issuer_mode` (blueprint)      | `per_provider`                                           | Makes Authentik return the per-app URL as issuer, matching `SSO_AUTHORITY`                                 |
| `haven-email-verified` mapping | `return {'email_verified': True}`                        | Authentik does not auto-verify emails for manually created accounts; Vaultwarden rejects unverified emails |

> ⚠️ Do **not** set `issuer_mode: global` for Vaultwarden — Authentik does not expose a global discovery document, so Vaultwarden will get a 404 and fail to discover the provider.

> ⚠️ Do **not** change `SSO_AUTHORITY` to the root URL (`https://auth.huybrechts.xyz/`) — that results in an issuer mismatch error even if discovery succeeds via a workaround.

**Login flow (for reference):**
1. Vaultwarden fetches `https://auth.huybrechts.xyz/application/o/vaultwarden/.well-known/openid-configuration`
2. Authentik returns `"issuer": "https://auth.huybrechts.xyz/application/o/vaultwarden/"` (matches `SSO_AUTHORITY` ✅)
3. User authenticates; token includes `email_verified: true` from the custom mapping (✅)
4. Vaultwarden accepts the token and prompts for master password

### WUD SSO env vars

WUD reads OIDC config from environment variables set in `config/hearth/modules/mod-wud.yaml`. `WUD_AUTH_OIDC_AUTHENTIK_CLIENTID`, `WUD_AUTH_OIDC_AUTHENTIK_CLIENTSECRET`, `WUD_AUTH_OIDC_AUTHENTIK_DISCOVERY`, and `WUD_PUBLIC_URL` are already wired. WUD is configured to auto-redirect to Authentik on login (skipping the WUD internal login page).