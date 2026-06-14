# Bitwarden and Vaultwarden for Haven

[Back to Guide](./GUIDE.md#setup-vaultwarden)

## Overview

Bitwarden is a popular open-source password manager. Vaultwarden is a lightweight, self-hosted implementation of the Bitwarden API, written in Rust. It offers similar features and compatibility with Bitwarden clients while being more resource-efficient and easier to deploy on personal servers.

## Initial Setup

1. `https://vault.huybrechts.xyz/admin` → enter the **plain-text** `VAULTWARDEN_ADMIN_TOKEN`
2. General Settings → Allow new signups → **enable** → Save
3. `https://vault.huybrechts.xyz/#/register` → create user accounts
4. Admin panel → Allow new signups → **disable** → Save
5. Test login at `https://vault.huybrechts.xyz/#/login`
6. Configure email (SMTP) for password reset notifications
7. Test password reset flow
8. Configure Authentik as SSO provider
   - Admin panel → Single Sign-On → Add provider → OpenID Connect
   - Provider URL: `https://auth.huybrechts.xyz/if/realms/master/protocol/openid-connect`
   - Client ID: `vaultwarden`
   - Save, then test SSO login

## Vaultwarden Steps

| #   | Task                                          |
| --- | --------------------------------------------- |
| 1   | Deploy Vaultwarden via Docker Compose         |
| 2   | Configure OIDC via Authentik                  |
| 3   | Import Bitwarden JSON export                  |
| 4   | Create user accounts for all 5 family members |
| 5   | Set up Collections: Family / Dev / CI-Infra   |
| 6   | Reconfigure Bitwarden client on admin devices |
| 7   | Verify autofill and all entries accessible    |
| 8   | Roll out to family devices                    |

## Vaultwarden vs Bitwarden

Bitwarden is used to store the "break-the-glass" credentials needed to recover from a total platform failure, such as losing access to GitHub or Hetzner accounts. Vaultwarden is the self-hosted service running on the haven platform that provides password management for the family.

Vaultwarden is deployed as a Docker container on the haven platform, with its own SQLite database. It is accessible at `vault.huybrechts.xyz` and supports all standard Bitwarden clients (mobile apps, browser extensions, desktop apps) using the same API. The admin token for Vaultwarden is generated during the initial setup and stored securely in Bitwarden for emergency access.

This way we keep the infrastructure secrets (API tokens, database passwords, etc.) separate from personal credentials (website logins, personal notes, etc.) while still using the same underlying password management technology. If Vaultwarden is compromised, the infrastructure secrets in Bitwarden remain safe. Break-glass is put in Bitwarden, not Vaultwarden.
