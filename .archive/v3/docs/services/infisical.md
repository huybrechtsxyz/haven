# Infisical for Haven

## Overview

Infisical is a secrets management platform designed for developers and teams. It provides a secure way to store, manage, and access sensitive information such as API keys, database credentials, and other secrets. Infisical offers features like role-based access control, audit logs, and integration with various development tools.

## Initial Setup

The initial setup of Infisical involves creating an admin account, configuring the first organization and project, and enabling multi-factor authentication (MFA) for enhanced security.

1. Go to <https://app.infisical.com> → Sign Up → create the first admin account (use github sso for convenience)
2. Complete the onboarding wizard (create an organisation and a first project)

> **ONLY SSO** — Infisical Cloud supports GitHub SSO for the first admin account.

**Enable MFA (TOTP):**

1. Log in to <https://app.infisical.com>
2. Top-right avatar → Personal Settings → Security → Two-Factor Authentication → Enable
3. Scan the QR code with an authenticator app (e.g. Vaultwarden TOTP, Aegis, or Authy)
4. Enter the verification code to confirm → Save
5. Store the backup codes in Vaultwarden under "Infisical Admin — MFA backup codes"

> MFA is per-user and opt-in. For an admin-only tool with GitHub SSO, enabling TOTP is strongly recommended.

**Organization and Project:**

1. Log in to <https://app.infisical.com>
2. Top-left orgname → Settings (bottom) → Update Organization Name
3. Go to secret management → Projects → Create New Project `haven` → Save

**Machine token (for CLI):**

1. Log in to <https://app.infisical.com>
2. Go to secret management → Projects → Select `haven`
3. Access Control → Machine Identities → Create New Token
4. Add Machine Identity to Project - `haven-github-actions` → Save
5. Machine Identity details → Universal Auth
6. Save the Machine Identity Client Id to Bitwarden
7. Create a new Machine Identity Client Secret `haven-github-client` and save Bitwarden
