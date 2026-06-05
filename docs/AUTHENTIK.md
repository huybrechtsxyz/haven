# Authentik Configuration Guide

> How to configure Authentik as the SSO identity provider for all haven services.

**URL:** <https://auth.huybrechts.xyz>  
**Version:** 2026.5.2 (pinned in `config/hearth/modules/mod-authentik.yaml`)  
**Container:** `haven-authentik-server-1` + `haven-authentik-worker-1`

---

## Initial Setup

### 1. Create admin account

1. Navigate to `https://auth.huybrechts.xyz/if/flow/initial-setup/`
2. Set the admin email (e.g. `admin@huybrechts.xyz`)
3. Set a strong password — store in Vaultwarden under "Authentik Admin"
4. Complete the wizard

> ⚠️ This URL only works once. After the first admin is created, it redirects to login.

### 2. Configure email (SMTP)

Required for password resets and notification emails.

SMTP is configured via environment variables on the server and worker containers (defined in `config/hearth/modules/mod-authentik.yaml`). **No UI configuration needed** — the settings are injected at deploy time.

| Setting  | Value                      | Source                                     |
| -------- | -------------------------- | ------------------------------------------ |
| Host     | `smtp.gmail.com`           | Module definition                          |
| Port     | `587` (STARTTLS)           | Module definition                          |
| Username | SMTP account               | GitHub Secret: `AUTHENTIK_EMAIL__USERNAME` |
| Password | App password               | GitHub Secret: `AUTHENTIK_EMAIL__PASSWORD` |
| From     | `authentik@huybrechts.xyz` | Module definition                          |

After deploying, test delivery from the worker container:

```bash
docker compose exec worker ak test_email your@email.com
```

### 3. Branding (optional)

1. Admin Interface → System → Brands → Edit `authentik-default`
2. Set:
   - Title: `Haven`
   - Logo: upload a logo or leave default
   - Favicon: upload or leave default
3. Save

---

## Create Family Users

### Add users

1. Admin Interface → Directory → Users → Create
2. For each family member:
   - Username: first name (lowercase)
   - Name: full name
   - Email: `<name>@huybrechts.xyz`
   - Group: add to `authentik Admins` (for you) or create a `family` group (for everyone else)
3. Set initial password or send enrollment email

### Create groups

| Group    | Members            | Purpose                       |
| -------- | ------------------ | ----------------------------- |
| `admins` | You                | Full admin access to all apps |
| `family` | All family members | Standard access to all apps   |

1. Admin Interface → Directory → Groups → Create
2. Add members to each group

### Enforce MFA (recommended)

1. Admin Interface → Flows & Stages → Stages → Create
2. Type: `Authenticator Validation Stage`
3. Configure: require TOTP or WebAuthn
4. Add this stage to the default authentication flow (after password stage)

---

## OIDC Application: Vaultwarden

### Create OAuth2 provider

1. Admin Interface → Applications → Providers → Create
2. Type: **OAuth2/OpenID Connect**
3. Settings:
   - Name: `Vaultwarden`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Client ID: `vaultwarden` (or auto-generated — note it down)
   - Client Secret: generate and copy
   - Redirect URIs: `https://vault.huybrechts.xyz/identity/connect/oidc-signin`
   - Signing Key: select `authentik Self-signed Certificate`
4. Save

### Create application

1. Admin Interface → Applications → Applications → Create
2. Settings:
   - Name: `Vaultwarden`
   - Slug: `vaultwarden`
   - Provider: select the provider created above
   - Launch URL: `https://vault.huybrechts.xyz`
3. Save

### Configure Vaultwarden

In the Vaultwarden admin panel (`https://vault.huybrechts.xyz/admin`):

1. OpenID Connect Authentication → Enable
2. Settings:
   - Authority: `https://auth.huybrechts.xyz/application/o/vaultwarden/`
   - Client ID: _(from provider above)_
   - Client Secret: _(from provider above)_
   - SSO Organization name: `haven`

> Store the Client ID and Secret in Vaultwarden itself under "Haven SSO — Vaultwarden".

---

## OIDC Application: Infisical

### Create OAuth2 provider

1. Admin Interface → Applications → Providers → Create
2. Type: **OAuth2/OpenID Connect**
3. Settings:
   - Name: `Infisical`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Client ID: `infisical`
   - Client Secret: generate and copy
   - Redirect URIs: `https://secrets.huybrechts.xyz/api/v1/sso/oidc/callback`
   - Signing Key: select `authentik Self-signed Certificate`
4. Save

### Create application

1. Admin Interface → Applications → Applications → Create
2. Settings:
   - Name: `Infisical`
   - Slug: `infisical`
   - Provider: select the provider created above
   - Launch URL: `https://secrets.huybrechts.xyz`
3. Save

### Configure Infisical

In the Infisical dashboard (`https://secrets.huybrechts.xyz`):

1. Settings → Authentication → OIDC
2. Settings:
   - Issuer: `https://auth.huybrechts.xyz/application/o/infisical/`
   - Authorization endpoint: `https://auth.huybrechts.xyz/application/o/authorize/`
   - Token endpoint: `https://auth.huybrechts.xyz/application/o/token/`
   - Userinfo endpoint: `https://auth.huybrechts.xyz/application/o/userinfo/`
   - Client ID: _(from provider above)_
   - Client Secret: _(from provider above)_
3. Save and test

> Store the Client ID and Secret in Vaultwarden under "Haven SSO — Infisical".

---

## OIDC Application: Immich (future — forge)

### Create OAuth2 provider

1. Admin Interface → Applications → Providers → Create
2. Type: **OAuth2/OpenID Connect**
3. Settings:
   - Name: `Immich`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Client ID: `immich`
   - Client Secret: generate and copy
   - Redirect URIs: `https://photos.huybrechts.xyz/auth/login`
   - Signing Key: select `authentik Self-signed Certificate`
4. Save

### Create application

1. Admin Interface → Applications → Applications → Create
2. Settings:
   - Name: `Immich`
   - Slug: `immich`
   - Provider: select the provider created above
   - Launch URL: `https://photos.huybrechts.xyz`
3. Save

### Configure Immich

In Immich admin settings:

1. Administration → OAuth Settings → Enable
2. Settings:
   - Issuer URL: `https://auth.huybrechts.xyz/application/o/immich/`
   - Client ID: _(from provider above)_
   - Client Secret: _(from provider above)_
   - Scope: `openid email profile`
   - Auto Register: Enable
   - Button Text: `Sign in with Haven`
3. Save

> Store the Client ID and Secret in Vaultwarden under "Haven SSO — Immich".

---

## Troubleshooting

### Can't access initial setup URL

The initial setup flow is only available when no admin account exists. If you've already created one, log in normally at `https://auth.huybrechts.xyz/if/flow/default-authentication-flow/`.

### OIDC redirect fails

- Check the Redirect URI matches exactly (trailing slashes matter)
- Verify the application slug in the Issuer URL matches the slug in Authentik
- Check Authentik logs: Admin Interface → Events → Logs

### Password reset email not sending

- SMTP is configured via env vars — check `AUTHENTIK_EMAIL__*` secrets are set in GitHub
- Re-deploy to pick up secret changes: `run_deploy: true`
- Test from container: `docker compose exec worker ak test_email your@email.com`
- Check the Tasks page for failed email tasks (Admin → Events → Tasks)
- Verify the from-address domain has valid SPF/DKIM records

### Token exchange errors

- Ensure Signing Key is configured on the provider
- Ensure the client secret matches between Authentik and the service
- Check that the Authorization flow includes consent (use `implicit-consent` for internal apps)

---

## Reference

### Authentik URLs

| Endpoint             | URL                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------- |
| User dashboard       | `https://auth.huybrechts.xyz/if/user/`                                              |
| Admin interface      | `https://auth.huybrechts.xyz/if/admin/`                                             |
| OpenID Configuration | `https://auth.huybrechts.xyz/application/o/<slug>/.well-known/openid-configuration` |

### Provider settings summary

| App         | Client ID     | Redirect URI                                                |
| ----------- | ------------- | ----------------------------------------------------------- |
| Vaultwarden | `vaultwarden` | `https://vault.huybrechts.xyz/identity/connect/oidc-signin` |
| Infisical   | `infisical`   | `https://secrets.huybrechts.xyz/api/v1/sso/oidc/callback`   |
| Immich      | `immich`      | `https://photos.huybrechts.xyz/auth/login`                  |
