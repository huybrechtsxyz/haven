# Bitwarden and Vaultwarden for Haven

## Overview

Bitwarden is a popular open-source password manager. Vaultwarden is a lightweight, self-hosted implementation of the Bitwarden API, written in Rust. It offers similar features and compatibility with Bitwarden clients while being more resource-efficient and easier to deploy on personal servers.

## Bitwarden Setup

1. Sign up for a Bitwarden account at <https://bitwarden.com> (free tier is sufficient).
2. Enable MFA on your Bitwarden account:
   - Install **Bitwarden Authenticator** (free, iOS + Android) — this is the recommended TOTP app for all Haven accounts
   - In Bitwarden cloud: Settings → Security → Two-step login → Authenticator App
   - Scan the QR code with Bitwarden Authenticator
   - Store the recovery code **offline** (printed paper or USB) — this is the one credential that cannot be stored in the vault itself
3. Create a folder named **Haven** to store all infrastructure credentials and secrets.
4. Store the critical credentials in Bitwarden cloud (see the Secrets Inventory section in the guide for details on what to store).

## Vaultwarden Steps

Set up Vaultwarden on the haven platform to provide password management for the family. It will be accessible at `vault.{domain}` and supports all standard Bitwarden clients (mobile apps, browser extensions, desktop apps) using the same API.

1. `https://vault.{domain}/admin` → enter the **plain-text** `VAULTWARDEN_ADMIN_TOKEN`
2. General Settings → Allow new signups → **enable** → Save
3. `https://vault.{domain}/#/register` → create user accounts for all family members
4. Admin panel → Allow new signups → **disable** → Save
5. Test login at `https://vault.{domain}/#/login`
6. Configure email (SMTP) for password reset notifications
7. Test password reset flow
8. Configure Authentik as SSO provider:
   - Admin panel → Single Sign-On → Add provider → OpenID Connect
   - Provider URL: `https://auth.{domain}/application/o/vaultwarden/`
   - Client ID: `vaultwarden`
   - Save, then test SSO login
9. Point **Bitwarden Authenticator** app at `vault.{domain}` on family devices so TOTP seeds sync to Vaultwarden




---

## Vaultwarden vs Bitwarden

**Two-vault strategy** — family credentials and admin credentials are kept in separate vaults intentionally:

| Vault                               | Users          | Contents                                                                                         | Access when Hearth is down? |
| ----------------------------------- | -------------- | ------------------------------------------------------------------------------------------------ | --------------------------- |
| **Vaultwarden** (self-hosted)       | Family members | Day-to-day passwords, shared logins, TOTP codes                                                  | ❌ No                        |
| **Bitwarden cloud** (bitwarden.com) | Admin only     | Infrastructure accounts (INWX, GitHub, Hetzner, Infomaniak, Terraform), break-the-glass recovery | ✅ Yes                       |

**Why separate?** If Hearth fails, the admin needs to access provider accounts (Hetzner, INWX, GitHub) to diagnose and recover the platform. Those credentials must be reachable independent of Hearth. Keeping them in Bitwarden cloud ensures the admin can always act, even in a total Hearth outage.

**Bitwarden Authenticator** serves both vaults from a single app — TOTP codes for admin accounts sync to Bitwarden cloud; TOTP codes for family accounts sync to Vaultwarden.

**Vaultwarden admin token** is stored in Bitwarden cloud (not Vaultwarden itself) so it remains accessible for emergency administration if family members are locked out.
