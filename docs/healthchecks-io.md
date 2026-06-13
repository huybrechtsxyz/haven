# Healthchecks.io for Haven

[Back to Guide](./GUIDE.md#setup-healthchecksio)

## Overview

Healthchecks.io is a service for monitoring the uptime of your services. It allows you to create checks for your services and receive notifications if they go down.

## Initial Setup

Healthchecks.io monitors **cron job execution** — it alerts when a scheduled task (like BorgBackup) fails to check in on time.

1. Sign up at <https://healthchecks.io>
2. Create a project named `haven`
3. Create checks:

| Check name      | Period   | Grace  | Purpose                           |
| --------------- | -------- | ------ | --------------------------------- |
| `hearth-backup` | 24 hours | 1 hour | BorgBackup daily cron (02:00 UTC) |

4. Copy the ping URL (e.g. `https://hc-ping.com/<uuid>`)
5. Add it as GitHub Environment Variable `HEALTHCHECK_PING_URL_BACKUP`
6. Run pipeline with `run_config: true` to deploy the updated backup script
7. Configure alert integrations (email, Telegram, or Pushover)
8. Store credentials in Vaultwarden

> Healthchecks.io is for **dead man's switch** monitoring — it alerts on *absence* of activity. If the backup cron doesn't ping within 25 hours, you get an alert.
