# Hosting Migration — Working Guide

> Plan: [hosting-steps-v2.md](hosting-steps-v2.md) | Design: [hosting-design.md](hosting-design.md)
> This file is a living workbook. Fill in results as you go. Use it to track progress and collect the data needed for each next step.

**Status:** � In Progress

---

## Accounts & access (fill in as you create them)

| Service         | URL                              | Username                 | Credentials stored                          |
| --------------- | -------------------------------- | ------------------------ | ------------------------------------------- |
| INWX            | <https://www.inwx.de>            | <vincent@huybrechts.xyz> | Bitwarden (migrate to Vaultwarden → Family) |
| Hetzner         | <https://console.hetzner.cloud>  | <vincent@huybrechts.xyz> | Bitwarden (migrate to Vaultwarden → Family) |
| Infomaniak      | <https://manager.infomaniak.com> | <vincent@huybrechts.xyz> | Vaultwarden → Family                        |
| Healthchecks.io | <https://healthchecks.io>        | <vincent@huybrechts.xyz> | Vaultwarden → Family                        |
| UptimeRobot     | <https://uptimerobot.com>        | <vincent@huybrechts.xyz> | Vaultwarden → Family                        |

---

## Wave 1 — Infrastructure & Developer Services

**Wave 1 status:** � In Progress  
**Wave 1 started:** 2026-05-27  
**Wave 1 completed:** ___________

---

### Phase 1.1 — Domain transfer to INWX

**Status:** � In Progress

> **Decision: `meeus.family` will NOT be transferred.** Renewal cost jumps to ~€52/yr from year 2. Let it expire at Versio. Steps 3 and 7 are skipped.
>
> **`alderwyn.xyz` and `madebyjana.be`** are registered via ClouDNS (backend: PDR Ltd.) — NOT at Versio. Both expire **30 June 2026**. Contact ClouDNS support to unlock both and obtain EPP codes before initiating transfer at INWX. `madebyjana.be` is reserved for a daughter's website (static site on VPS via Caddy).
>
> Total domains to transfer: **4** — `huybrechts.xyz`, `huybrechts.dev`, `alderwyn.xyz`, `madebyjana.be`.

#### Before you begin — record current DNS

Run these commands and paste results below:

```powershell
Resolve-DnsName -Name huybrechts.xyz -Type MX
Resolve-DnsName -Name huybrechts.xyz -Type TXT
Resolve-DnsName -Name huybrechts.dev -Type MX
Resolve-DnsName -Name alderwyn.xyz -Type MX
Resolve-DnsName -Name madebyjana.be -Type MX
Resolve-DnsName -Name madebyjana.be -Type TXT
```

**details: Current DNS snapshot (fill in):**

```shell
# Captured 2026-05-27 (full scan)

### huybrechts.xyz  (NS: Versio)
MX    TTL 300  → aspmx.l.google.com (pri 1), alt1.aspmx (5), alt2.aspmx (5), alt3.aspmx (10), alt4.aspmx (10)
TXT   TTL 14400 → v=spf1 include:_spf.google.com ~all
DMARC → ⚠ NONE — no _dmarc.huybrechts.xyz record exists
A     TTL 300  → 185.237.97.232  (current VPS — must recreate at INWX after transfer)
DKIM  → (check Google Admin console for selector)

### huybrechts.dev  (NS: Versio)
MX    TTL 300  → aspmx.l.google.com (pri 1), alt1.aspmx (5), alt2.aspmx (5), alt3.aspmx (10), alt4.aspmx (10)
TXT   TTL 14400 → v=spf1 a mx ip4:185.182.56.120 a:spf.spamexperts.axc.nl ...  ⚠ legacy SPF — needs cleanup at kSuite cutover
TXT   TTL 14400 → google-site-verification=bTxhh5aX4S_y3NxxNiM8q7H-s-s3TAi...  ← must keep
DMARC TTL 1800 → (record exists but value is empty — needs investigation)
A     TTL 300  → 185.47.174.65  (old server — must recreate at INWX after transfer)

### alderwyn.xyz  → transferred to INWX 2026-05-27, no prior DNS records
### madebyjana.be → transfer in progress, no prior DNS records
```

#### Huybrechts.xyz dns records

| Type | Name                             | Priority | Value                                                                                                                                                                                                                                                                                                                                                                                                                      | TTL   |
| ---- | -------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| A    | huybrechts.xyz                   |          | 185.237.97.232                                                                                                                                                                                                                                                                                                                                                                                                             | 3600  |
| A    | www.huybrechts.xyz               |          | 185.237.97.232                                                                                                                                                                                                                                                                                                                                                                                                             | 3600  |
| A    | data.huybrechts.xyz              |          | 185.237.97.232                                                                                                                                                                                                                                                                                                                                                                                                             | 3600  |
| A    | docs.huybrechts.xyz              |          | 185.237.97.232                                                                                                                                                                                                                                                                                                                                                                                                             | 3600  |
| A    | test.huybrechts.xyz              |          | 45.147.248.102                                                                                                                                                                                                                                                                                                                                                                                                             | 3600  |
| A    | admin.huybrechts.xyz             |          | 185.237.97.232                                                                                                                                                                                                                                                                                                                                                                                                             | 14400 |
| A    | proxy.huybrechts.xyz             |          | 185.237.97.232                                                                                                                                                                                                                                                                                                                                                                                                             | 14400 |
| A    | develop.huybrechts.xyz           |          | 45.147.248.102                                                                                                                                                                                                                                                                                                                                                                                                             | 14400 |
| A    | staging.huybrechts.xyz           |          | 185.139.230.197                                                                                                                                                                                                                                                                                                                                                                                                            | 14400 |
| A    | data.test.huybrechts.xyz         |          | 45.147.248.102                                                                                                                                                                                                                                                                                                                                                                                                             | 14400 |
| A    | docs.test.huybrechts.xyz         |          | 45.147.248.102                                                                                                                                                                                                                                                                                                                                                                                                             | 14400 |
| A    | admin.test.huybrechts.xyz        |          | 45.147.248.102                                                                                                                                                                                                                                                                                                                                                                                                             | 14400 |
| A    | proxy.test.huybrechts.xyz        |          | 45.147.248.102                                                                                                                                                                                                                                                                                                                                                                                                             | 14400 |
| A    | data.staging.huybrechts.xyz      |          | 185.139.230.197                                                                                                                                                                                                                                                                                                                                                                                                            | 14400 |
| A    | docs.staging.huybrechts.xyz      |          | 185.139.230.197                                                                                                                                                                                                                                                                                                                                                                                                            | 14400 |
| A    | admin.staging.huybrechts.xyz     |          | 185.139.230.197                                                                                                                                                                                                                                                                                                                                                                                                            | 14400 |
| A    | proxy.staging.huybrechts.xyz     |          | 185.139.230.197                                                                                                                                                                                                                                                                                                                                                                                                            | 14400 |
| CAA  | huybrechts.xyz                   |          | 128 issue "letsencrypt.org"                                                                                                                                                                                                                                                                                                                                                                                                | 14400 |
| CAA  | test.huybrechts.xyz              |          | 128 issue "letsencrypt.org"                                                                                                                                                                                                                                                                                                                                                                                                | 14400 |
| CAA  | develop.huybrechts.xyz           |          | 128 issue "letsencrypt.org"                                                                                                                                                                                                                                                                                                                                                                                                | 14400 |
| CAA  | staging.huybrechts.xyz           |          | 128 issue "letsencrypt.org"                                                                                                                                                                                                                                                                                                                                                                                                | 14400 |
| MX   | huybrechts.xyz                   | 1        | ASPMX.L.GOOGLE.COM                                                                                                                                                                                                                                                                                                                                                                                                         | 14400 |
| MX   | huybrechts.xyz                   | 5        | ALT1.ASPMX.L.GOOGLE.COM                                                                                                                                                                                                                                                                                                                                                                                                    | 14400 |
| MX   | huybrechts.xyz                   | 5        | ALT2.ASPMX.L.GOOGLE.COM                                                                                                                                                                                                                                                                                                                                                                                                    | 14400 |
| MX   | huybrechts.xyz                   | 10       | ALT3.ASPMX.L.GOOGLE.COM                                                                                                                                                                                                                                                                                                                                                                                                    | 14400 |
| MX   | huybrechts.xyz                   | 10       | ALT4.ASPMX.L.GOOGLE.COM                                                                                                                                                                                                                                                                                                                                                                                                    | 14400 |
| TXT  | huybrechts.xyz                   |          | v=spf1 include:_spf.google.com ~all                                                                                                                                                                                                                                                                                                                                                                                        | 14400 |
| TXT  | mail.huybrechts.xyz              |          | ghs.googlehosted.com                                                                                                                                                                                                                                                                                                                                                                                                       | 14400 |
| TXT  | drive.huybrechts.xyz             |          | ghs.googlehosted.com                                                                                                                                                                                                                                                                                                                                                                                                       | 14400 |
| TXT  | sites.huybrechts.xyz             |          | ghs.googlehosted.com                                                                                                                                                                                                                                                                                                                                                                                                       | 14400 |
| TXT  | groups.huybrechts.xyz            |          | ghs.googlehosted.com                                                                                                                                                                                                                                                                                                                                                                                                       | 14400 |
| TXT  | calendar.huybrechts.xyz          |          | ghs.googlehosted.com                                                                                                                                                                                                                                                                                                                                                                                                       | 14400 |
| TXT  | google._domainkey.huybrechts.xyz |          | v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiCjizCB50u956pZGH4mvL7G6X7EEUkluhr6OGB2/b5TmEXSLWEC8wCjoAeERfHwQ/uPvZ0icaE43R5nNXPfIvLgjiS+Jed18MUydLrbChZTfl4kbX2JL2I/VAc+XsxqnBuU+XiTMis1KS2Zkg4jtAs07vPMTUuSpWt3I16S9dG7fk/mzTND8alq3zFd/MxBVWz3P48JZN6T5sW6yokWO2MWQdaMoyvNgU3FcWF+VvYWL4B8sqKWl8cqiD1d3MLT45gsF4xRJ/Jd7sWzcX+IAWbUTdEVBcrQB1vAZVJ1WTgaoOKPmjVV2gLGehvHsXBjlf9vsBDy9x8G4xCo9yTxWoQIDAQAB | 14400 |


#### Huybrechts.dev dns records

| Type | Name                     | Priority | Value                                                                | TTL   |
| ---- | ------------------------ | -------- | -------------------------------------------------------------------- | ----- |
| A    | huybrechts.dev           |          | 185.47.174.65                                                        | 3600  |
| A    | *.huybrechts.dev         |          | 185.47.174.65                                                        | 3600  |
| A    | s3.huybrechts.dev        |          | 185.47.174.65                                                        | 3600  |
| A    | *.s3.huybrechts.dev      |          | 185.47.174.65                                                        | 3600  |
| A    | auth.huybrechts.dev      |          | 185.47.174.65                                                        | 600   |
| A    | redis.huybrechts.dev     |          | 185.47.174.65                                                        | 600   |
| A    | consul.huybrechts.dev    |          | 185.47.174.65                                                        | 600   |
| A    | pgadmin.huybrechts.dev   |          | 185.47.174.65                                                        | 600   |
| A    | traefik.huybrechts.dev   |          | 185.47.174.65                                                        | 3600  |
| A    | identity.huybrechts.dev  |          | 185.47.174.65                                                        | 600   |
| A    | localhost.huybrechts.dev |          | 127.0.0.1                                                            | 3600  |
| CAA  | huybrechts.dev           |          | 0 issue "letsencrypt.org"                                            | 3600  |
| CAA  | *.huybrechts.dev         |          | 0 issue "letsencrypt.org"                                            | 3600  |
| CAA  | s3.huybrechts.dev        |          | 0 issue "letsencrypt.org"                                            | 3600  |
| CAA  | *.s3.huybrechts.dev      |          | 0 issue "letsencrypt.org"                                            | 3600  |
| CAA  | auth.huybrechts.dev      |          | 0 issue "letsencrypt.org"                                            | 600   |
| CAA  | redis.huybrechts.dev     |          | 0 issue "letsencrypt.org"                                            | 600   |
| CAA  | consul.huybrechts.dev    |          | 0 issue "letsencrypt.org"                                            | 600   |
| CAA  | pgadmin.huybrechts.dev   |          | 0 issue "letsencrypt.org"                                            | 600   |
| CAA  | traefik.huybrechts.dev   |          | 0 issue "letsencrypt.org"                                            | 3600  |
| CAA  | identity.huybrechts.dev  |          | 0 issue "letsencrypt.org"                                            | 600   |
| MX   | huybrechts.dev           | 1        | ASPMX.L.GOOGLE.COM                                                   | 14400 |
| MX   | huybrechts.dev           | 5        | ALT2.ASPMX.L.GOOGLE.COM                                              | 14400 |
| MX   | huybrechts.dev           | 5        | ALT1.ASPMX.L.GOOGLE.COM                                              | 14400 |
| MX   | huybrechts.dev           | 10       | ALT4.ASPMX.L.GOOGLE.COM                                              | 14400 |
| MX   | huybrechts.dev           | 10       | ALT3.ASPMX.L.GOOGLE.COM                                              | 14400 |
| TXT  | huybrechts.dev           |          | google-site-verification=bTxhh5aX4S_y3NxxNiM8q7H-s-s3TAikLKtqZ6yBWYI | 14400 |
| TXT  | huybrechts.dev           |          | v=spf1 a mx ip4:185.182.56.120 a:spf.spamexperts.axc.nl ~all         | 14400 |


#### Steps

| #     | Task                                                                                    | Result / Notes                                                                                                                        | Done |
| ----- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1     | Unlock `huybrechts.xyz` at Versio                                                       | ✓ 2026-05-27                                                                                                                          | [x]  |
| 2     | Unlock `huybrechts.dev` at Versio                                                       | ✓ 2026-05-27                                                                                                                          | [x]  |
| ~~3~~ | ~~Unlock `meeus.family` at Versio~~                                                     | ✗ decommissioned — let expire at Versio                                                                                               | —    |
| 4     | Contact ClouDNS support — unlock `alderwyn.xyz` + `madebyjana.be` and request EPP codes | ✓ 2026-05-27 — tickets submitted, awaiting response                                                                                   | [x]  |
| 5     | Request EPP code for `huybrechts.xyz` at Versio                                         | ✓ 2026-05-27                                                                                                                          | [x]  |
| 6     | Request EPP code for `huybrechts.dev` at Versio                                         | ✓ 2026-05-27                                                                                                                          | [x]  |
| ~~7~~ | ~~Request EPP code for `meeus.family`~~                                                 | ✗ decommissioned — no transfer needed                                                                                                 | —    |
| 8     | Receive EPP codes for `alderwyn.xyz` + `madebyjana.be` from ClouDNS support             | `alderwyn.xyz` ✓ 2026-05-27 · `madebyjana.be` ✓ n/a (.be uses DNS.be email confirmation, no EPP code)                                 | [x]  |
| 9     | Initiate transfer for all 4 domains at INWX                                             | `alderwyn.xyz` ✓ STARTED · `huybrechts.dev` ✓ STARTED · `huybrechts.xyz` ✓ REQUESTED · `madebyjana.be` ✓ in progress — all 2026-05-27 | [x]  |
| 10    | Approve transfer confirmation emails                                                    |                                                                                                                                       | [ ]  |
| 11    | Confirm all 4 domains appear in INWX panel                                              | Completed: ___________                                                                                                                | [ ]  |
| 12    | Recreate DNS records at INWX for `huybrechts.xyz` and `huybrechts.dev` identically      | ⚠ MX must stay pointing to Google; `alderwyn.xyz` and `madebyjana.be` had no records — nothing to recreate                            | [ ]  |
| 13    | Enable WHOIS privacy on `huybrechts.xyz`, `huybrechts.dev`, `alderwyn.xyz`              | `alderwyn.xyz` ✓ 2026-05-27 · others pending · `.be` does not support WHOIS privacy                                                   | [ ]  |
| 14    | Send test email — verify mail still works                                               | Sent to / from: ___________ ✓                                                                                                         | [ ]  |

#### Expiry dates after transfer (fill in)

| Domain             | Expiry at INWX                                                |
| ------------------ | ------------------------------------------------------------- |
| `huybrechts.xyz`   |                                                               |
| `huybrechts.dev`   |                                                               |
| ~~`meeus.family`~~ | ✗ decommissioned — not transferred                            |
| `alderwyn.xyz`     | ✓ transferred 2026-05-27 — fill in new expiry from INWX panel |
| `madebyjana.be`    |                                                               |

---

### Phase 1.2 — Provision Hetzner VPS + Storage Box

**Status:** 🔴 Not started

#### Hetzner Steps

| #   | Task                                       | Result / Notes               | Done |
| --- | ------------------------------------------ | ---------------------------- | ---- |
| 1   | Create Hetzner project `huybrechts-family` |                              | [ ]  |
| 2   | Provision CPX31 VPS                        | Region: ___________          | [ ]  |
| 3   | Provision BX11 Storage Box                 | Region: ___________          | [ ]  |
| 4   | Add SSH public key to VPS                  | Key fingerprint: ___________ | [ ]  |
| 5   | Run `strata` bootstrap                     | Completed: ___________       | [ ]  |
| 6   | Deploy Caddy                               |                              | [ ]  |
| 7   | Verify Caddy HTTPS on VPS IP               |                              | [ ]  |

#### Server details (fill in)

```data
VPS IP:           ___.___.___.___ 
Storage Box host: ___________
Storage Box user: ___________
SSH key:          ~/.ssh/___________
```

#### DNS — add A records at INWX for VPS subdomains

| Subdomain                | Record type | Value      | Added |
| ------------------------ | ----------- | ---------- | ----- |
| `photos.huybrechts.xyz`  | A           | `<VPS_IP>` | [ ]   |
| `vault.huybrechts.xyz`   | A           | `<VPS_IP>` | [ ]   |
| `secrets.huybrechts.xyz` | A           | `<VPS_IP>` | [ ]   |
| `auth.huybrechts.xyz`    | A           | `<VPS_IP>` | [ ]   |
| `status.huybrechts.xyz`  | A           | `<VPS_IP>` | [ ]   |

---

### Phase 1.3 — Deploy Authentik (SSO)

**Status:** 🔴 Not started  
**URL:** <https://auth.huybrechts.xyz>

#### Authentik Steps

| #   | Task                                              | Result / Notes                     | Done |
| --- | ------------------------------------------------- | ---------------------------------- | ---- |
| 1   | Deploy Authentik via Docker Compose               |                                    | [ ]  |
| 2   | Create admin account                              | ⚠ Credentials in Vaultwarden → Dev | [ ]  |
| 3   | Enforce 2FA for all accounts                      | Method: TOTP / WebAuthn            | [ ]  |
| 4   | Create OIDC app for Vaultwarden                   | Client ID: ___________             | [ ]  |
| 5   | Create OIDC app for Immich                        | Client ID: ___________             | [ ]  |
| 6   | Create OIDC app for Infisical                     | Client ID: ___________             | [ ]  |
| 7   | Create user accounts for all 5 family members     |                                    | [ ]  |
| 8   | Test login flow (redirect + token exchange works) |                                    | [ ]  |

#### Authentik OIDC client secrets

> ⚠ Store all client secrets in Infisical (once deployed) or Vaultwarden in the meantime. Do not fill in here.

---

### Phase 1.4 — Deploy Vaultwarden (passwords)

**Status:** 🔴 Not started  
**URL:** <https://vault.huybrechts.xyz>

#### Vaultwarden Steps

| #   | Task                                          | Result / Notes                 | Done |
| --- | --------------------------------------------- | ------------------------------ | ---- |
| 1   | Deploy Vaultwarden via Docker Compose         |                                | [ ]  |
| 2   | Configure OIDC via Authentik                  |                                | [ ]  |
| 3   | Import Bitwarden JSON export                  | Items imported: ___________    | [ ]  |
| 4   | Create user accounts for all 5 family members |                                | [ ]  |
| 5   | Set up Collections: Family / Dev / CI-Infra   |                                | [ ]  |
| 6   | Reconfigure Bitwarden client on admin devices | Server: vault.huybrechts.xyz ✓ | [ ]  |
| 7   | Verify autofill and all entries accessible    |                                | [ ]  |
| 8   | Roll out to family devices                    | Last device done: ___________  | [ ]  |
| 9   | Start 2-week soak period                      | Soak started: ___________      | [ ]  |
| 10  | Cancel Bitwarden Team after soak              | Cancelled: ___________         | [ ]  |

### Devices migrated to Vaultwarden

| Device | Owner | Done |
| ------ | ----- | ---- |
|        |       | [ ]  |
|        |       | [ ]  |
|        |       | [ ]  |
|        |       | [ ]  |
|        |       | [ ]  |

---

### Phase 1.5 — Deploy Infisical (secrets)

**Status:** 🔴 Not started  
**URL:** <https://secrets.huybrechts.xyz>

#### Infisical Steps

| #   | Task                                                  | Result / Notes        | Done |
| --- | ----------------------------------------------------- | --------------------- | ---- |
| 1   | Deploy Infisical via Docker Compose                   |                       | [ ]  |
| 2   | Configure Authentik SSO (admin-only)                  |                       | [ ]  |
| 3   | Create projects per app                               | Projects: ___________ | [ ]  |
| 4   | Create production + staging environments              |                       | [ ]  |
| 5   | Seed with all service credentials                     |                       | [ ]  |
| 6   | Update Docker Compose services to pull from Infisical |                       | [ ]  |
| 7   | Audit `haven` repo — no hardcoded secrets in git      | Verified: ___________ | [ ]  |

---

### Phase 1.6 — Deploy Immich (photos)

**Status:** 🔴 Not started  
**URL:** <https://photos.huybrechts.xyz>

#### Immich Steps

| #   | Task                                                           | Result / Notes               | Done |
| --- | -------------------------------------------------------------- | ---------------------------- | ---- |
| 1   | Deploy Immich via Docker Compose                               |                              | [ ]  |
| 2   | Configure OIDC via Authentik                                   |                              | [ ]  |
| 3   | Export Google Photos via Takeout (all users, original quality) | Export size: ___________ GB  | [ ]  |
| 4   | Upload photo library to Immich                                 | Photos uploaded: ___________ | [ ]  |
| 5   | Verify albums, dates, metadata                                 |                              | [ ]  |
| 6   | Install Immich app on family phones                            |                              | [ ]  |
| 7   | Enable auto-upload on each phone                               |                              | [ ]  |
| 8   | Face recognition indexing complete                             | Completed: ___________       | [ ]  |

### Phones with Immich auto-upload enabled

| Phone | Owner | Done |
| ----- | ----- | ---- |
|       |       | [ ]  |
|       |       | [ ]  |
|       |       | [ ]  |
|       |       | [ ]  |
|       |       | [ ]  |

---

### Phase 1.7 — Backups & monitoring

**Status:** 🔴 Not started

#### Backup Steps

| #   | Task                                            | Result / Notes                                 | Done |
| --- | ----------------------------------------------- | ---------------------------------------------- | ---- |
| 1   | Configure BorgBackup cron (daily → Storage Box) | Cron: `0 2 * * *`                              | [ ]  |
| 2   | Store BorgBackup encryption key in Vaultwarden  | ⚠ Key stored: Vaultwarden → Dev → BorgBackup   | [ ]  |
| 3   | Run first backup manually                       | Duration: ___________ Size: ___________        | [ ]  |
| 4   | Test full restore from BorgBackup               | Restore tested: ___________                    | [ ]  |
| 5   | Deploy Gatus health dashboard                   | URL: <https://status.huybrechts.xyz>           | [ ]  |
| 6   | Register Healthchecks.io dead-man's switch      | Check UUID: ___________                        | [ ]  |
| 7   | Set up UptimeRobot monitors                     | Monitors: vault, photos, auth, secrets, status | [ ]  |

### BorgBackup details

```data
Repo:       ssh://___@___________/./backups
Key:        stored in Vaultwarden (do not write here)
Schedule:   daily at 02:00
Retention:  daily 7, weekly 4, monthly 6
Last run:   ___________
Last size:  ___________
```

---

## Phase 1.8 — Decommission Kamatera + Bitwarden

**Status:** 🔴 Not started

### Wave 1 soak gate (2 weeks from last service deployed)

- [ ] Soak started: ___________
- [ ] All VPS services running stable
- [ ] BorgBackup running daily without failures
- [ ] Vaultwarden adopted by all family members
- [ ] Immich photo upload working on all phones
- [ ] No unplanned downtime events

### Decommission Steps

| #   | Task                                         | Result / Notes         | Done |
| --- | -------------------------------------------- | ---------------------- | ---- |
| 1   | Verify no traffic/services still on Kamatera |                        | [ ]  |
| 2   | Final backup of Kamatera data                | Saved to: ___________  | [ ]  |
| 3   | Decommission Kamatera VPS                    | Cancelled: ___________ | [ ]  |
| 4   | Cancel Bitwarden Team (if not done in 1.4)   | Cancelled: ___________ | [ ]  |

**Wave 1 complete:** ___________

---

## Wave 2 — Email, Files & Collaboration (Google → kSuite)

> **Do not start Wave 2 until the Wave 1 soak gate above is fully checked.**

**Wave 2 status:** 🔴 Not started  
**Wave 2 started:** ___________  
**Wave 2 completed:** ___________

---

### Phase 2.1 — Preparation & exports

**Status:** 🔴 Not started

#### Preparation & Export Steps

| #   | Task                                            | Result / Notes              | Done |
| --- | ----------------------------------------------- | --------------------------- | ---- |
| 1   | Create Infomaniak account                       | ✓ 2026-05-27                | [x]  |
| 2   | Export Gmail — MBOX (all 3 users)               | Export sizes: ___________   | [ ]  |
| 3   | Export Google Contacts — vCard (all 3 users)    |                             | [ ]  |
| 4   | Export Google Calendar — ICS (all 3 users)      |                             | [ ]  |
| 5   | Export Google Drive (all 3 users)               | Export size: ___________ GB | [ ]  |
| 6   | Validate MBOX files (spot-check in Thunderbird) | ✓                           | [ ]  |
| 7   | Confirm vCard/ICS open correctly                | ✓                           | [ ]  |
| 8   | Confirm Drive export complete                   | ✓                           | [ ]  |

---

### Phase 2.2 — Provision kSuite

**Status:** 🔴 Not started

#### Provisioning Steps

| #     | Task                                                   | Result / Notes                          | Done |
| ----- | ------------------------------------------------------ | --------------------------------------- | ---- |
| 1     | Purchase kSuite plan (5 users, kDrive 3 TB+)           | Plan: ___________ Cost: ___________ /mo | [ ]  |
| 2     | Add + verify `huybrechts.xyz`                          | Verified: ___________                   | [ ]  |
| 3     | Add + verify `huybrechts.dev`                          | Verified: ___________                   | [ ]  |
| ~~4~~ | ~~Add + verify `meeus.family`~~                        | ✗ decommissioned                        | —    |
| 5     | Add + verify `alderwyn.xyz`                            | Verified: ___________                   | [ ]  |
| 6     | Create 5 mailboxes on `huybrechts.xyz`                 |                                         | [ ]  |
| 7     | Configure aliases across alias domains                 |                                         | [ ]  |
| 8     | Create `family@huybrechts.xyz` group (all 5)           |                                         | [ ]  |
| 9     | Create any additional groups                           | Groups: ___________                     | [ ]  |
| 10    | Configure child mail forwarding (child → both parents) |                                         | [ ]  |
| 11    | Generate DKIM keys per domain in kSuite                | Note DNS records to add — see below     | [ ]  |

#### kSuite mailboxes (fill in real names)

| Mailbox           | Family member | Aliases configured | Done |
| ----------------- | ------------- | ------------------ | ---- |
| `@huybrechts.xyz` |               |                    | [ ]  |
| `@huybrechts.xyz` |               |                    | [ ]  |
| `@huybrechts.xyz` |               |                    | [ ]  |
| `@huybrechts.xyz` |               |                    | [ ]  |
| `@huybrechts.xyz` |               |                    | [ ]  |

#### DKIM keys from kSuite (fill in per domain)

> Copy these from kSuite Manager → Mail → DKIM. Add to INWX DNS in Phase 2.4.

| Domain             | DKIM selector    | DNS TXT value |
| ------------------ | ---------------- | ------------- |
| `huybrechts.xyz`   |                  |               |
| `huybrechts.dev`   |                  |               |
| ~~`meeus.family`~~ | ✗ decommissioned | —             |
| `alderwyn.xyz`     |                  |               |

---

### Phase 2.3 — Data migration (parallel period)

**Status:** 🔴 Not started  
> Google still active. kSuite ready but MX not switched yet.

#### Email history

| #   | Task                                        | Result / Notes                 | Done |
| --- | ------------------------------------------- | ------------------------------ | ---- |
| 1   | Run Infomaniak IMAP migration tool (user 1) | Messages migrated: ___________ | [ ]  |
| 2   | Run Infomaniak IMAP migration tool (user 2) | Messages migrated: ___________ | [ ]  |
| 3   | Run Infomaniak IMAP migration tool (user 3) | Messages migrated: ___________ | [ ]  |
| 4   | Verify folder structure and message counts  | ✓                              | [ ]  |

#### Contacts & Calendar

| #   | Task                                       | Result / Notes        | Done |
| --- | ------------------------------------------ | --------------------- | ---- |
| 1   | Import vCard into kSuite Contacts (user 1) | Contacts: ___________ | [ ]  |
| 2   | Import vCard into kSuite Contacts (user 2) | Contacts: ___________ | [ ]  |
| 3   | Import vCard into kSuite Contacts (user 3) | Contacts: ___________ | [ ]  |
| 4   | Import ICS into kSuite Calendar (user 1)   | Events: ___________   | [ ]  |
| 5   | Import ICS into kSuite Calendar (user 2)   | Events: ___________   | [ ]  |
| 6   | Import ICS into kSuite Calendar (user 3)   | Events: ___________   | [ ]  |
| 7   | Verify shared calendars and contact groups | ✓                     | [ ]  |

#### Files

| #   | Task                                    | Result / Notes                | Done |
| --- | --------------------------------------- | ----------------------------- | ---- |
| 1   | Install kDrive desktop client           |                               | [ ]  |
| 2   | Upload Google Drive export to kDrive    | Size uploaded: ___________ GB | [ ]  |
| 3   | Set up shared folder structure          |                               | [ ]  |
| 4   | Verify file counts and document formats | ✓                             | [ ]  |

---

### Phase 2.4 — DNS cutover (MX switch)

**Status:** 🔴 Not started  
**Cutover window planned:** ___________ (evening/weekend)

#### Pre-cutover checklist — all must be ✓ before proceeding

- [ ] All email history imported and verified in kSuite
- [ ] Contacts and calendars imported
- [ ] DKIM keys from kSuite recorded in section 2.2
- [ ] All 5 mailboxes tested via kSuite webmail
- [ ] Forwarding rules verified (test email to child → parents received copy)
- [ ] `family@huybrechts.xyz` group tested
- [ ] Family notified of cutover window
- [ ] TTL lowered to 300s at INWX (48h before cutover)

#### DNS records to change at INWX (for all 4 domains)

> Fill in exact values from kSuite Manager before executing.

**Infomaniak MX records:**

```data
MX priority / host:  ___________  (from kSuite panel)
```

**SPF:**

```data
v=spf1 include:spf.infomaniak.ch ~all
```

**DMARC (start with p=none):**

```data
v=DMARC1; p=none; rua=mailto:dmarc@huybrechts.xyz
```

#### Execute cutover

| #     | Task                                           | Result / Notes         | Done |
| ----- | ---------------------------------------------- | ---------------------- | ---- |
| 1     | Switch MX for `huybrechts.xyz`                 | Time: ___________      | [ ]  |
| 2     | Switch MX for `huybrechts.dev`                 | Time: ___________      | [ ]  |
| ~~3~~ | ~~Switch MX for `meeus.family`~~               | ✗ decommissioned       | —    |
| 4     | Switch MX for `alderwyn.xyz`                   | Time: ___________      | [ ]  |
| 5     | Update SPF for all 3 domains                   |                        | [ ]  |
| 6     | Add DKIM records for all 3 domains             |                        | [ ]  |
| 7     | Add DMARC records for all 3 domains            |                        | [ ]  |
| 8     | Send test email (external → each mailbox)      | ✓ all 5 delivered      | [ ]  |
| 9     | Send test email FROM each kSuite mailbox       | ✓ delivered outbound   | [ ]  |
| 10    | Check headers: DKIM=pass, SPF=pass, DMARC=pass | ✓                      | [ ]  |
| 11    | Test child → parent forwarding                 | ✓                      | [ ]  |
| 12    | Test `family@huybrechts.xyz` group             | ✓ all 5 received       | [ ]  |
| 13    | Monitor kSuite logs for 24h                    | No errors: ___________ | [ ]  |

### Rollback (if critical issue within 24h)

1. Revert MX to Google (`aspmx.l.google.com` etc.) at INWX
2. Revert SPF to Google include
3. Wait ~5 min for TTL propagation
4. Investigate and note issue here: ___________

---

### Phase 2.5 — Client configuration

**Status:** 🔴 Not started

#### kSuite connection settings (fill in from kSuite panel)

```data
IMAP server:    ___________   Port: ___
SMTP server:    ___________   Port: ___
CalDAV URL:     ___________
CardDAV URL:    ___________
ActiveSync URL: ___________
```

#### Devices

| Device | Owner | Email | CalDAV | CardDAV | kDrive app | Done |
| ------ | ----- | ----- | ------ | ------- | ---------- | ---- |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |

---

### Phase 2.6 — Decommission Google Workspace

**Status:** 🔴 Not started

#### Wave 2 soak gate (2 weeks from MX cutover)

- [ ] Soak started: ___________
- [ ] No missed/bounced emails reported
- [ ] All family members receiving and sending normally
- [ ] Calendars and contacts syncing on all devices
- [ ] kDrive working for file access

#### Wave 2 Steps

| #   | Task                                       | Result / Notes              | Done |
| --- | ------------------------------------------ | --------------------------- | ---- |
| 1   | Verify no mail still going to Gmail        | Last straggler: ___________ | [ ]  |
| 2   | Final Google Takeout archive (safety copy) | Stored on: ___________      | [ ]  |
| 3   | Cancel Google Workspace                    | Cancelled: ___________      | [ ]  |
| 4   | Remove Google OAuth grants / app passwords |                             | [ ]  |

**Wave 2 complete:** ___________

---

### Phase 2.7 — Post-migration hardening

**Status:** 🔴 Not started

| #   | Task                                                                  | Target date           | Done |
| --- | --------------------------------------------------------------------- | --------------------- | ---- |
| 1   | Raise DNS TTL back to 3600s (1 week after cutover)                    |                       | [ ]  |
| 2   | DMARC `p=none` → `p=quarantine` (after 2 weeks, review `rua` reports) |                       | [ ]  |
| 3   | DMARC `p=quarantine` → `p=reject` (after 4 weeks)                     |                       | [ ]  |
| 4   | Set up monthly kSuite cold export to VPS (IMAP pull + CalDAV/CardDAV) |                       | [ ]  |
| 5   | Write family runbook (password reset, add device, add alias)          |                       | [ ]  |
| 6   | Share emergency access credentials with trusted person                |                       | [ ]  |
| 7   | Schedule monthly maintenance window                                   | Day/time: ___________ | [ ]  |

---

### Final cost summary (fill in after Wave 2)

| Item                            | Cost        |
| ------------------------------- | ----------- |
| Infomaniak kSuite (actual plan) | €___/mo     |
| Hetzner CPX31 VPS               | €15/mo      |
| Hetzner BX11 Storage Box        | ~€4/mo      |
| INWX domains (~€76/yr)          | ~€6.30/mo   |
| **Total**                       | **€___/mo** |
| **Previous spend**              | ~€58-81/mo  |
| **Saving**                      | **€___/mo** |

---

*Plan: [hosting-steps-v2.md](hosting-steps-v2.md) | Design: [hosting-design.md](hosting-design.md)*
