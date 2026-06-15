# Infisical for Haven

[Back to Guide](./GUIDE.md#setup-infisical)

## Overview

Infisical is a secrets management platform designed for developers and teams. It provides a secure way to store, manage, and access sensitive information such as API keys, database credentials, and other secrets. Infisical offers features like role-based access control, audit logs, and integration with various development tools.

## Initial Setup

The initial setup of Infisical involves creating an admin account, configuring the first organization and project, and enabling multi-factor authentication (MFA) for enhanced security.

1. `https://secrets.huybrechts.xyz` → Sign Up → create the first admin account (email + password)
2. Store credentials in Vaultwarden under "Infisical Admin"
3. Complete the onboarding wizard (create an organisation and a first project)

> **No SSO** — Infisical OIDC SSO requires the Pro plan (paid). Login with email + password only. This is acceptable since Infisical is an admin-only tool.

**Enable MFA (TOTP):**

1. Log in to `https://secrets.huybrechts.xyz`
2. Top-right avatar → Personal Settings → Security → Two-Factor Authentication → Enable
3. Scan the QR code with an authenticator app (e.g. Vaultwarden TOTP, Aegis, or Authy)
4. Enter the verification code to confirm → Save
5. Store the backup codes in Vaultwarden under "Infisical Admin — MFA backup codes"

> MFA is per-user and opt-in. For an admin-only tool with no SSO, enabling TOTP is strongly recommended.
