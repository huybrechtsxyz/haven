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

### 3. Branding

Branding is configured automatically by the blueprint — the `authentik-default` brand domain is updated to `auth.huybrechts.xyz` with title `Haven`.

> ⚠️ One-time prerequisite: rename the existing default brand's domain from `*` to `auth.huybrechts.xyz` in the UI before the first blueprint apply: Admin Interface → System → Brands → edit `authentik-default` → set Domain to `auth.huybrechts.xyz` → Save.

---

## Create Family Users

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

MFA is configured automatically by the blueprint — the `default-authentication-mfa-validation` stage is bound to the login flow at order `30` (after password at `20`).

After deploy, verify: Admin Interface → Flows & Stages → Flows → `default-authentication-flow` → Stage Bindings tab should show `10` identification → `20` password → `30` mfa-validation.

Users without MFA configured will be prompted to set up TOTP on their next login.

---

## Authentication strategy

**Not all services use Authentik SSO.** SSO adds complexity and creates a single point of failure — if Authentik is down, SSO-protected services become inaccessible. The strategy is:

| Service         | Auth method                  | Reason                                                 |
| --------------- | ---------------------------- | ------------------------------------------------------ |
| **Vaultwarden** | Authentik SSO                | Family-facing — ease of access for all users           |
| **WUD**         | Authentik SSO                | Admin tool, but already working and low-friction       |
| **Portainer**   | Local credentials + TOTP MFA | Admin tool — must stay accessible if Authentik is down |
| **Infisical**   | Local credentials + TOTP MFA | Admin tool — must stay accessible if Authentik is down |

> ⚠️ **Do not configure SSO for Portainer or Infisical.** If Authentik fails, you need these tools to diagnose and fix the problem. Keep them on independent local auth.

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

### Portainer — local auth + MFA

Portainer uses its own local credentials, **not** Authentik SSO. This is intentional — Portainer must remain accessible even if Authentik is down.

**Enable TOTP MFA (one-time per user):**
1. Log in at `https://portainer.huybrechts.xyz`
2. Click your username (top right) → My account
3. Scroll to **Two-factor authentication** → enable
4. Scan the QR code with your authenticator app
5. Store the recovery codes in Vaultwarden under "Portainer MFA recovery"

### Infisical — local auth + MFA

Infisical uses its own local credentials, **not** Authentik SSO. This is intentional — Infisical must remain accessible even if Authentik is down (it stores the secrets needed to fix Authentik).

**Enable TOTP MFA (one-time per user):**
1. Log in at `https://secrets.huybrechts.xyz`
2. User menu (top right) → Security
3. Enable **Two-factor authentication** → TOTP
4. Scan the QR code with your authenticator app
5. Store the recovery codes in Vaultwarden under "Infisical MFA recovery"

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

### `insufficient_scope` after successful redirect

**Symptom:** Browser redirects to Authentik, user authenticates, but the service returns `insufficient_scope` or similar token error.

**Cause:** The OAuth2 provider has no `property_mappings` configured, so Authentik issues a token with no scope claims (no `openid`, `email`, or `profile` data).

**Fix:** In the blueprint, add `property_mappings` to every provider:

```yaml
property_mappings:
  - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
  - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
  - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
```

Or manually in the UI: Admin → Applications → Providers → \<provider\> → Edit → Advanced Protocol Settings → Scopes → add `openid`, `email`, `profile`.

### `ECONNREFUSED <public-ip>:443` from inside Docker

**Symptom:** A container (e.g. WUD) tries to reach a public hostname like `https://auth.huybrechts.xyz` and gets `ECONNREFUSED` against the server's public IP, even though the service is running.

**Cause:** Docker containers on a bridge network cannot route back to the host via its public IP (hairpin NAT is not enabled). DNS resolves `auth.huybrechts.xyz` → `91.98.78.36`, which is unreachable from inside the `haven_default` network.

**Fix:** Add network aliases to the Caddy service so Docker DNS resolves the public hostnames to Caddy's internal IP instead:

```yaml
# config/hearth/modules/mod-caddy.yaml — inside the caddy service entry
configuration:
  networks:
    default:
      aliases:
        - auth.huybrechts.xyz
        - wud.huybrechts.xyz
        - vault.huybrechts.xyz
        - secrets.huybrechts.xyz
        - portainer.huybrechts.xyz
```

This is already configured in `mod-caddy.yaml`. If you add a new public hostname, add it to this list and redeploy.

**Verify aliases are active:**
```bash
docker inspect haven-caddy-1 --format '{{json .NetworkSettings.Networks}}'
# Look for "Aliases" containing your hostnames
```

### WUD OIDC fails at startup (registers before Authentik is ready)

**Symptom:** WUD logs show OIDC registration error at startup even though Authentik is running.

**Cause:** WUD registers OIDC once at startup. If it starts before Authentik is healthy, registration fails silently and SSO never works for that session.

**Fix:** Two safeguards are in place in the deploy pipeline:
1. `depends_on: authentik-server: condition: service_healthy` in the generated compose — WUD waits for Authentik's healthcheck before starting.
2. The deploy playbook explicitly restarts WUD after waiting for Authentik to report `healthy`.

If SSO stops working after a deploy, `docker restart haven-wud-1` while Authentik is healthy will fix it.

### Blueprint not applied / `ls: cannot open directory '/blueprints/custom/': Permission denied`

**Symptom:** Blueprint appears in the Authentik admin UI (System → Blueprints) but fails to apply, or is never discovered by the worker. Container-level inspection shows permission denied on `/blueprints/custom/`.

**Cause:** The blueprint directory on the host (`/opt/haven/etc/authentik/blueprints`) has mode `0750` (owner-only access). The Authentik worker container runs as uid 1000, which is not the `haven` user and has no group membership — so it cannot traverse the directory.

**Fix:** The config playbook (`hearth-config.yml`) sets the directory to `0755`. If it regresses, run `run_config=true` to re-apply. Verify on the host:
```bash
stat /opt/haven/etc/authentik/blueprints
# Should show: Access: (0755/drwxr-xr-x)
```

And from inside the container:
```bash
docker exec haven-authentik-worker-1 ls /blueprints/custom/
# Should list: haven-apps.yaml
```

### Vaultwarden SSO: `unexpected issuer URI`

**Symptom:**
```
Failed to discover OpenID provider: Validation error: unexpected issuer URI
`https://auth.huybrechts.xyz/` (expected `https://auth.huybrechts.xyz/application/o/vaultwarden/`)
```

**Cause:** `issuer_mode: global` was set on the Authentik provider. Authentik returns `https://auth.huybrechts.xyz/` as the issuer, but Vaultwarden's `SSO_AUTHORITY` points to the per-app URL.

**Fix:** The blueprint uses `issuer_mode: per_provider` for Vaultwarden. Re-run `run_config=true` to ensure the blueprint is current, then check in the Authentik UI: Admin → Applications → Providers → Vaultwarden → Advanced Protocol Settings → Issuer mode must be `Per Provider`.

> Do **not** change `SSO_AUTHORITY` to the root URL — Authentik has no global `/.well-known/openid-configuration` endpoint, so discovery will return 404.

### Vaultwarden SSO: `Email is not verified by the SSO provider`

**Symptom:** Login reaches Authentik, user authenticates, but Vaultwarden rejects with "Email is not verified by the SSO provider."

**Cause:** Authentik does not auto-mark emails as verified for manually created accounts. The OIDC token is missing `email_verified: true`.

**Fix (automatic):** The blueprint includes a custom `haven-email-verified` scope mapping that injects `email_verified: True` into every token issued to Vaultwarden. Re-run `run_config=true` to ensure the mapping is applied. Verify in Authentik: Admin → Applications → Providers → Vaultwarden → Advanced Protocol Settings → Scope Mappings — should include `haven-email-verified`.

**Fix (manual, per user):** In the Authentik admin UI: Directory → Users → select user → Edit → check "Email verified" → Save. Do this for all users.

---

## Reference

### Authentik URLs

| Endpoint             | URL                                                                                 |
| -------------------- | ----------------------------------------------------------------------------------- |
| User dashboard       | `https://auth.huybrechts.xyz/if/user/`                                              |
| Admin interface      | `https://auth.huybrechts.xyz/if/admin/`                                             |
| OpenID Configuration | `https://auth.huybrechts.xyz/application/o/<slug>/.well-known/openid-configuration` |

### Provider settings summary

| App         | Client ID     | Redirect URI                                                  | Policy                 |
| ----------- | ------------- | ------------------------------------------------------------- | ---------------------- |
| Vaultwarden | `vaultwarden` | `https://vault.huybrechts.xyz/identity/connect/oidc-signin`   | `policy-group-members` |
| WUD         | `wud`         | `https://wud.huybrechts.xyz/auth/oidc/authentik/cb`           | `policy-group-admins`  |
| Portainer   | —             | Local auth + TOTP MFA (no SSO — must work if Authentik down)  | —                      |
| Immich      | `immich`      | `https://photos.huybrechts.xyz/auth/login` _(future — forge)_ | —                      |
| Infisical   | —             | Local auth + TOTP MFA (no SSO — must work if Authentik down)  | —                      |
