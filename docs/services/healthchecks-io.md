# Healthchecks.io for Haven

## Overview

Healthchecks.io is a service for monitoring the uptime of your services. It allows you to create checks for your services and receive notifications if they go down.

## Initial Setup

Healthchecks.io monitors **cron job execution** — it alerts when a scheduled task (like BorgBackup) fails to check in on time.

1. Sign up at <https://healthchecks.io>
2. Enable MFA immediately after account creation:
   - Go to Account -> Two-factor authentication
   - Scan QR code with **Bitwarden Authenticator**
   - Store the TOTP seed and recovery code in **Bitwarden cloud** (not Vaultwarden)
3. Store the Healthchecks.io account credentials in **Bitwarden cloud**.



---

---------------------------------------------------------------------------------------

---



## Service Setup

1. Create a project named `haven` to group all related checks for the haven platform.
2. Create a check named `hearth-backup` with the following settings:
   - Period: 24 hours
   - Grace: 1 hour
   - Purpose: Monitor the daily BorgBackup cron job (scheduled at 02:00 UTC)

| Check name      | Period   | Grace  | Purpose                           |
| --------------- | -------- | ------ | --------------------------------- |
| `hearth-backup` | 24 hours | 1 hour | BorgBackup daily cron (02:00 UTC) |

4. Copy the ping URL (e.g. `https://hc-ping.com/<uuid>`)
5. Add it to Infisical Cloud as `HEALTHCHECK_PING_BACKUP` (see [setup.md → Infisical Secrets](../guides/setup.md#secrets-overview))
6. Add it to Bitwarden, linked to the Healthchecks.io account entry
7. Run pipeline with `run_config: true` to deploy the updated backup script
8. Configure alert integrations (email, Telegram, or Pushover)
9. Store credentials in Vaultwarden

> Healthchecks.io is for **dead man's switch** monitoring — it alerts on *absence* of activity. If the backup cron doesn't ping within 25 hours, you get an alert.
