# Migration Plan v2 — Gradual Migration

> Source: [hosting-design.md](hosting-design.md)
> Strategy: **Two-wave approach.** Wave 1 migrates developer/infrastructure services (VPS, passwords, secrets, photos) while Google Workspace stays active. Wave 2 migrates email, files, calendar, and contacts to kSuite after Wave 1 is proven stable.

---

## Why gradual?

- VPS services (Vaultwarden, Immich, Infisical, Authentik) only affect the admin — low blast radius.
- Google Workspace email affects the whole family daily — highest risk, migrate last.
- Domain transfer can happen early (MX stays on Google until Wave 2 cutover).
- Allows family to keep using Gmail/Drive/Calendar with zero disruption during Wave 1.

---

## Pre-requisites

- [ ] Hetzner Cloud account created
- [ ] INWX account created
- [ ] `strata` and `haven` repos cloned and ready
- [ ] Bitwarden export prepared (JSON format)
- [ ] Google Photos Takeout initiated (only photos needed for Wave 1)

> Note: Infomaniak account and full Google Takeout (mail/contacts/calendar/drive) are **not** needed until Wave 2.

---

# Wave 1 — Infrastructure & Developer Services

> Goal: Hetzner VPS fully operational, Kamatera decommissioned, Bitwarden Team replaced. Google Workspace untouched.

---

## Phase 1.1 — Domain transfer to INWX

> Domains move to INWX early so all DNS is under one roof. MX records stay pointing to Google.

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Document current DNS records for all 4 domains | `dig` / registrar panel screenshots | [ ] |
| 2 | Note current MX, SPF, DKIM, DMARC for all domains | `dig MX/TXT` per domain | [ ] |
| 3 | Unlock domains at current registrar (Versio) | Disable transfer lock | [ ] |
| 4 | Request EPP/auth codes for all 4 domains | One code per domain | [ ] |
| 5 | Initiate transfer at INWX | Enter EPP codes; pay transfer fee | [ ] |
| 6 | Approve transfer confirmation emails | Sent to registrant email | [ ] |
| 7 | Wait for transfer completion (5–7 days) | `.xyz` and `.dev` typically 5 days | [ ] |
| 8 | Verify domains appear in INWX panel | Check expiry dates renewed | [ ] |
| 9 | **Recreate ALL existing DNS records at INWX identically** | MX stays on Google! | [ ] |
| 10 | Enable WHOIS privacy on all 4 domains | INWX → Domain → ID Protection | [ ] |
| 11 | Verify email still works after transfer | Send/receive test emails | [ ] |

---

## Phase 1.2 — Provision Hetzner VPS + Storage Box

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Create Hetzner project (`huybrechts-family`) | | [ ] |
| 2 | Provision CPX31 VPS (Falkenstein or Nuremberg) | 4 vCPU, 8 GB RAM, 160 GB SSD | [ ] |
| 3 | Provision BX11 Storage Box (1 TB) | Same region as VPS | [ ] |
| 4 | Add SSH key to VPS | Key from admin's workstation | [ ] |
| 5 | Run `strata` bootstrap against `haven` config | OS hardening, Docker, UFW, Fail2Ban | [ ] |
| 6 | Deploy Caddy (reverse proxy + auto-TLS) | Subdomain routing config in `haven` | [ ] |
| 7 | Verify Caddy responds on VPS IP | HTTP → HTTPS redirect works | [ ] |

### DNS for VPS subdomains (at INWX)

Add A records pointing to VPS IP (does not affect email):

```
photos.huybrechts.xyz    → A → <VPS_IP>
vault.huybrechts.xyz     → A → <VPS_IP>
secrets.huybrechts.xyz   → A → <VPS_IP>
auth.huybrechts.xyz      → A → <VPS_IP>
status.huybrechts.xyz    → A → <VPS_IP>
```

---

## Phase 1.3 — Deploy Authentik (SSO)

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Deploy Authentik via Docker Compose | Behind Caddy on `auth.huybrechts.xyz` | [ ] |
| 2 | Create admin account | Strong password + TOTP 2FA | [ ] |
| 3 | Create OIDC provider applications | One per service (Vaultwarden, Immich, Infisical) | [ ] |
| 4 | Create user accounts for all 5 family members | Will be used for photos/passwords | [ ] |
| 5 | Enforce 2FA for all accounts | TOTP or WebAuthn | [ ] |
| 6 | Test login flow | Verify redirect and token exchange | [ ] |

---

## Phase 1.4 — Deploy Vaultwarden (passwords)

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Deploy Vaultwarden via Docker Compose | Behind Caddy on `vault.huybrechts.xyz` | [ ] |
| 2 | Configure OIDC login via Authentik | SSO as primary auth | [ ] |
| 3 | Import Bitwarden JSON export | Admin vault import | [ ] |
| 4 | Create all 5 user accounts | Via Authentik SSO or invite | [ ] |
| 5 | Set up Collections (Family / Dev / CI-Infra) | Match current Bitwarden org | [ ] |
| 6 | Reconfigure Bitwarden clients on admin devices first | Point to `vault.huybrechts.xyz` | [ ] |
| 7 | Verify autofill, sync, and all entries accessible | | [ ] |
| 8 | Roll out to family devices (one by one) | Change server URL in app | [ ] |
| 9 | **Keep Bitwarden Team active for 2 weeks** | Fallback during soak | [ ] |
| 10 | After 2-week soak: cancel Bitwarden Team | Saves ~€15/mo immediately | [ ] |

---

## Phase 1.5 — Deploy Infisical (secrets & config)

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Deploy Infisical via Docker Compose | Behind Caddy on `secrets.huybrechts.xyz` | [ ] |
| 2 | Configure Authentik SSO (admin-only access) | | [ ] |
| 3 | Create projects per app | | [ ] |
| 4 | Create environments (production, staging) | | [ ] |
| 5 | Seed with all service credentials | API keys, DB passwords, tokens | [ ] |
| 6 | Update Docker Compose services to pull from Infisical | Via CLI/SDK env injection | [ ] |
| 7 | Remove hardcoded secrets from `haven` repo | Audit git history | [ ] |

---

## Phase 1.6 — Deploy Immich (photos)

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Deploy Immich via Docker Compose | Behind Caddy on `photos.huybrechts.xyz` | [ ] |
| 2 | Configure OIDC login via Authentik | | [ ] |
| 3 | Export Google Photos via Takeout (original quality) | All 3 existing users | [ ] |
| 4 | Upload photo library to Immich | Web UI bulk upload or CLI | [ ] |
| 5 | Verify albums, dates, metadata preserved | | [ ] |
| 6 | Install Immich mobile app on family phones | Enable auto-upload | [ ] |
| 7 | Confirm face recognition indexing completes | May take hours for large libraries | [ ] |
| 8 | Family uses Immich for new photos going forward | Google Photos becomes archive | [ ] |

---

## Phase 1.7 — Backups & monitoring

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Configure BorgBackup cron (daily → Storage Box) | Encryption key stored in Vaultwarden | [ ] |
| 2 | Test full restore from BorgBackup | Validate cycle works | [ ] |
| 3 | Deploy Gatus health checks | Per-service endpoints | [ ] |
| 4 | Register Healthchecks.io dead-man's switch | Alert if backup misses schedule | [ ] |
| 5 | Set up UptimeRobot for public endpoint monitoring | vault, photos, auth, secrets | [ ] |

---

## Phase 1.8 — Decommission Kamatera + Bitwarden

> Only after all VPS services are stable for 2+ weeks.

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Verify no traffic/services still running on Kamatera | Check logs, DNS | [ ] |
| 2 | Final backup of Kamatera data (if any remains) | | [ ] |
| 3 | Decommission Kamatera VPS | Cancel subscription | [ ] |
| 4 | Cancel Bitwarden Team subscription | Already done if soak passed | [ ] |
| 5 | Update `hosting-design.md` — mark Wave 1 complete | | [ ] |

### Wave 1 savings achieved

| Item removed | Monthly saving |
|---|---|
| Bitwarden Team | ~€15/mo |
| Kamatera VPS | ~€20-40/mo |
| **Total Wave 1 savings** | **~€35-55/mo** |

| Item added | Monthly cost |
|---|---|
| Hetzner CPX31 | €15/mo |
| Hetzner BX11 Storage Box | ~€4/mo |
| Domains (4 × INWX) | ~€6.30/mo |
| **Total new cost** | **~€25/mo** |

> Google Workspace continues at ~€18/mo during Wave 1. Family experiences no disruption.

---

# Wave 2 — Email, Files & Collaboration (Google → kSuite)

> Goal: Replace Google Workspace entirely. Mail, calendar, contacts, and files move to Infomaniak kSuite.
> Start Wave 2 only after Wave 1 is stable for at least 2–4 weeks.

---

## Phase 2.1 — Preparation & exports

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Create Infomaniak account (admin) | | [ ] |
| 2 | Export Gmail (all 3 users) — MBOX via Google Takeout | | [ ] |
| 3 | Export Google Contacts (all 3 users) — vCard `.vcf` | | [ ] |
| 4 | Export Google Calendar (all 3 users) — ICS `.ics` | | [ ] |
| 5 | Export Google Drive (all 3 users) — via Takeout or rclone | | [ ] |
| 6 | Validate MBOX files (spot-check in Thunderbird) | | [ ] |
| 7 | Confirm vCard/ICS files open correctly | | [ ] |
| 8 | Confirm Drive export has all folders and documents | | [ ] |

---

## Phase 2.2 — Provision kSuite

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Purchase kSuite plan (5 users, kDrive 3 TB+) | Swiss data residency | [ ] |
| 2 | Add primary domain `huybrechts.xyz` | Verify ownership via DNS TXT at INWX | [ ] |
| 3 | Add alias domains: `huybrechts.dev`, `meeus.family`, `alderwyn.xyz` | Each verified via TXT | [ ] |
| 4 | Create 5 mailboxes on `huybrechts.xyz` | One per family member | [ ] |
| 5 | Configure aliases across alias domains | e.g. `user@huybrechts.dev` → `user@huybrechts.xyz` | [ ] |
| 6 | Create distribution group `family@huybrechts.xyz` | Members: all 5 | [ ] |
| 7 | Create any additional groups needed | e.g. `kids@`, `parents@` | [ ] |
| 8 | Configure child mail forwarding rules | Each child → copy to both parents | [ ] |
| 9 | Generate DKIM keys per domain in kSuite | Note the DNS records to add later | [ ] |
| 10 | **Do NOT switch MX yet** | kSuite ready but not receiving | [ ] |

---

## Phase 2.3 — Data migration (parallel period)

> Google Workspace still active. kSuite provisioned but MX not switched.

### Email history

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Use Infomaniak IMAP migration tool | Connects to Gmail IMAP, pulls all mail | [ ] |
| 2 | Alternative: `imapsync --host1 imap.gmail.com --host2 mail.infomaniak.com` | | [ ] |
| 3 | Verify folder structure and message counts match | Spot-check sent, inbox, labels | [ ] |
| 4 | Repeat for all 3 existing users | 2 new users have no history | [ ] |

### Contacts & Calendar

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Import vCard files into kSuite Contacts (per user) | | [ ] |
| 2 | Import ICS files into kSuite Calendar (per user) | | [ ] |
| 3 | Verify shared calendars and contact groups | | [ ] |

### Files (Google Drive → kDrive)

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Install kDrive desktop client on admin machine | | [ ] |
| 2 | Upload Google Drive export to kDrive | | [ ] |
| 3 | Set up shared folder structure for family | Replicate Team Drives | [ ] |
| 4 | Verify file counts, folder structure, formats | Google Docs → DOCX/XLSX via Takeout | [ ] |

---

## Phase 2.4 — DNS cutover (MX switch)

> **Critical cutover point.** Plan for a low-traffic window (evening/weekend).

### Pre-cutover checklist

- [ ] All email history imported and verified in kSuite
- [ ] Contacts and calendars imported
- [ ] kSuite DKIM keys ready to add to DNS
- [ ] All 5 mailboxes active and accessible via webmail
- [ ] Forwarding rules verified (send test to child → parents receive)
- [ ] Family notified of the switch and timeline
- [ ] Rollback plan ready (revert MX to Google within 5 min)

### TTL preparation (48h before cutover)

Lower TTL on MX/SPF/TXT records to 300s (5 min) at INWX. This enables fast rollback.

### Execute cutover

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Switch MX records for all 4 domains to Infomaniak | `mx.infomaniak.com` (check kSuite panel for exact values) | [ ] |
| 2 | Update SPF records | `v=spf1 include:spf.infomaniak.ch ~all` | [ ] |
| 3 | Add DKIM records (per domain) | Keys from kSuite | [ ] |
| 4 | Add DMARC records | Start with `p=none; rua=mailto:dmarc@huybrechts.xyz` | [ ] |
| 5 | Send test emails from external → each mailbox | Verify delivery | [ ] |
| 6 | Send test emails FROM each kSuite mailbox | Verify outbound + SPF/DKIM pass | [ ] |
| 7 | Check email headers | Confirm DKIM=pass, SPF=pass, DMARC=pass | [ ] |
| 8 | Test forwarding (child → parents) | | [ ] |
| 9 | Test `family@huybrechts.xyz` group | Delivers to all 5 | [ ] |
| 10 | Test alias domain delivery | `user@huybrechts.dev` etc. | [ ] |
| 11 | Monitor kSuite bounce/error logs for 24h | | [ ] |

### Rollback (if needed)

1. Revert MX records to Google (`aspmx.l.google.com` etc.)
2. Revert SPF to Google include
3. Wait 5 min (TTL)
4. Investigate and retry

---

## Phase 2.5 — Client configuration (family devices)

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Configure kSuite email on iPhones/iPads | IMAP/SMTP or ActiveSync | [ ] |
| 2 | Configure kSuite email on desktops | Thunderbird / Outlook | [ ] |
| 3 | Set up CalDAV sync on all devices | kSuite CalDAV URL | [ ] |
| 4 | Set up CardDAV sync on all devices | kSuite CardDAV URL | [ ] |
| 5 | Install kDrive app on phones | iOS / Android | [ ] |
| 6 | Install kDrive desktop sync (optional) | macOS / Windows | [ ] |
| 7 | Remove Google account from devices (after soak) | Or leave as read-only archive | [ ] |

---

## Phase 2.6 — Decommission Google Workspace

> Only after 2-week soak period with no email issues.

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Verify no mail still going to Gmail | Check Google inbox for stragglers | [ ] |
| 2 | Final Google Takeout export (safety archive) | Store on kDrive or VPS | [ ] |
| 3 | Cancel Google Workspace subscription | End billing (~€18/mo saved) | [ ] |
| 4 | Remove Google app passwords / connected apps | Clean up OAuth grants | [ ] |

---

## Phase 2.7 — Post-migration hardening

| # | Task | Notes | Done |
|---|------|-------|------|
| 1 | Raise DNS TTL back to 3600s | After 1 week stable | [ ] |
| 2 | Tighten DMARC: `p=none` → `p=quarantine` → `p=reject` | Over 2–4 weeks, monitoring `rua` reports | [ ] |
| 3 | Add MTA-STS records (if kSuite supports) | Enhances inbound TLS enforcement | [ ] |
| 4 | Set up periodic kSuite data export to VPS | Cold backup: IMAP pull + CalDAV/CardDAV export monthly | [ ] |
| 5 | Create family runbook | Password resets, new alias, add device, backup restore | [ ] |
| 6 | Share emergency access with trusted person | Sealed envelope or Vaultwarden emergency kit | [ ] |
| 7 | Schedule monthly maintenance window | Image updates, backup test, review logs | [ ] |

---

## Timeline

| Phase | Duration | Can overlap with |
|-------|----------|------------------|
| **Wave 1** | | |
| 1.1 — Domain transfer | 5–7 days (waiting) | 1.2 |
| 1.2 — VPS provisioning | 1–2 days | 1.1 |
| 1.3 — Authentik | 0.5 day | After 1.2 |
| 1.4 — Vaultwarden | 0.5 day | After 1.3 |
| 1.5 — Infisical | 0.5 day | After 1.3 |
| 1.6 — Immich | 1 day | After 1.3 |
| 1.7 — Backups & monitoring | 0.5 day | After 1.2 |
| 1.8 — Decommission old | After 2-week soak | — |
| **Wave 1 total** | ~3 weeks (incl. soak) | |
| | | |
| **Wave 2** | | |
| 2.1 — Preparation | 1–2 days | — |
| 2.2 — kSuite provisioning | 1 day | 2.1 |
| 2.3 — Data migration | 2–3 days | After 2.2 |
| 2.4 — DNS cutover | 1 evening | After 2.3 |
| 2.5 — Client config | 1–2 days | After 2.4 |
| 2.6 — Decommission Google | After 2-week soak | — |
| 2.7 — Hardening | Ongoing | After 2.4 |
| **Wave 2 total** | ~3 weeks (incl. soak) | |

**Total elapsed: ~6 weeks** — but the family only experiences disruption during the Wave 2 cutover evening. Wave 1 is invisible to them.

---

## Decision gate between waves

Before starting Wave 2, confirm:

- [ ] All VPS services stable for 2+ weeks (no unplanned downtime)
- [ ] BorgBackup tested and running daily
- [ ] Vaultwarden adopted by all family members
- [ ] Immich photo upload working on all phones
- [ ] Kamatera fully decommissioned
- [ ] Bitwarden Team cancelled
- [ ] Admin comfortable with ops burden

If any of these are not met, extend Wave 1 soak period before proceeding.

---

*Back to: [hosting-design.md](hosting-design.md) | See also: [hosting-steps.md](hosting-steps.md) (big-bang variant)*
