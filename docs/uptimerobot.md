# Uptimerobot

[Back to Guide](./GUIDE.md#setup-uptimerobot)

## Overview

UptimeRobot is a monitoring service that checks the availability of websites and services. It provides APIs to manage monitors, retrieve uptime statistics, and receive alerts.

## Initial Setup

UptimeRobot monitors **service availability** — it alerts when a URL returns errors or becomes unreachable.

1. Sign up at <https://uptimerobot.com>
2. Add HTTPS monitors (keyword check for 200 OK):

| Monitor name | URL                                | Interval | Keyword         |
| ------------ | ---------------------------------- | -------- | --------------- |
| Authentik    | `https://auth.huybrechts.xyz`      | 5 min    | _(none needed)_ |
| Vaultwarden  | `https://vault.huybrechts.xyz`     | 5 min    | _(none needed)_ |
| Infisical    | `https://secrets.huybrechts.xyz`   | 5 min    | _(none needed)_ |
| Portainer    | `https://portainer.huybrechts.xyz` | 5 min    | _(none needed)_ |
| WUD          | `https://wud.huybrechts.xyz`       | 5 min    | _(none needed)_ |

3. Configure alert contacts (email + optional Telegram/Pushover)
4. Optional: create a public status page (paid feature):
   - UptimeRobot → My Settings → Public Status Pages → New Status Page
   - Add all three monitors
   - Custom domain: `status.huybrechts.xyz`
   - Add CNAME record at INWX:
     ```
     status.huybrechts.xyz  CNAME  stats.uptimerobot.com  3600
     ```
5. Store credentials in Vaultwarden

> UptimeRobot free tier gives 50 monitors at 5-minute intervals — more than enough for haven.
