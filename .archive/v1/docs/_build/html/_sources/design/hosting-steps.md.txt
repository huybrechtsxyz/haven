# Migration Plan — Step by Step

> Source: [hosting-design.md](hosting-design.md)
> Scope: Migrate from Google Workspace (3 users) + Kamatera VPS + Bitwarden Team → Infomaniak kSuite (5 users) + Hetzner VPS + Vaultwarden.

---

## Pre-requisites

- [ ] Infomaniak account created (admin)
- [ ] Hetzner Cloud account created
- [ ] INWX account created
- [ ] `strata` and `haven` repos cloned and ready
- [ ] Bitwarden export prepared (JSON format)
- [ ] Google Takeout initiated for all 3 current Google Workspace users (mail, drive, photos, contacts, calendar)

---

## Phase 0 — Preparation (before any changes)

### 0.1 Inventory & export

| #   | Task                                                      | Tool / Method                       | Done |
| --- | --------------------------------------------------------- | ----------------------------------- | ---- |
| 1   | Export Gmail (all 3 users) — MBOX via Google Takeout      | Google Takeout                      | [ ]  |
| 2   | Export Google Contacts (all 3 users) — vCard `.vcf`       | Google Contacts → Export            | [ ]  |
| 3   | Export Google Calendar (all 3 users) — ICS `.ics`         | Google Calendar → Settings → Export | [ ]  |
| 4   | Export Google Drive (all 3 users) — via Takeout or rclone | `rclone sync` or Takeout ZIP        | [ ]  |
| 5   | Export Google Photos (all 3 users) — via Takeout          | Google Takeout (original quality)   | [ ]  |
| 6   | Export Bitwarden vault — JSON (encrypted)                 | Bitwarden web vault → Export        | [ ]  |
| 7   | Document current DNS records for all 4 domains            | `dig` / registrar panel screenshots | [ ]  |
| 8   | List all services running on Kamatera VPS                 | `docker ps`, systemd, notes         | [ ]  |
| 9   | Note current MX, SPF, DKIM, DMARC for all domains         | `dig MX/TXT` per domain             | [ ]  |

### 0.2 Validate exports

- [ ] Spot-check MBOX files (open in Thunderbird or `mbox-viewer`)
- [ ] Confirm vCard/ICS files open correctly
- [ ] Confirm Drive export has all shared drives / folders
- [ ] Confirm Photos export includes all albums at original resolution
- [ ] Confirm Bitwarden JSON import works in a test Vaultwarden instance

---

## Phase 1 — Domain transfer to INWX

> **Risk:** email downtime if MX records lapse during transfer. Mitigate by keeping MX unchanged until Phase 3.

| #   | Task                                                                                          | Notes                              | Done |
| --- | --------------------------------------------------------------------------------------------- | ---------------------------------- | ---- |
| 1   | Unlock domains at current registrar (Versio)                                                  | Disable transfer lock              | [ ]  |
| 2   | Request EPP/auth codes for `huybrechts.xyz`, `huybrechts.dev`, `alderwyn.xyz`, `meeus.family` | One code per domain                | [ ]  |
| 3   | Initiate transfer at INWX                                                                     | Enter EPP codes; pay transfer fee  | [ ]  |
| 4   | Approve transfer confirmation emails                                                          | Sent to registrant email           | [ ]  |
| 5   | Wait for transfer completion (1–7 days per domain)                                            | `.xyz` and `.dev` typically 5 days | [ ]  |
| 6   | Verify domains appear in INWX panel                                                           | Check expiry dates renewed         | [ ]  |
| 7   | **Do NOT change DNS records yet** — leave MX pointing to Google                               | Critical: mail must keep flowing   | [ ]  |
| 8   | Enable WHOIS privacy on all 4 domains (+€5/yr each)                                           | INWX → Domain → ID Protection      | [ ]  |

---

## Phase 2 — Provision Hetzner VPS + Storage Box

| #   | Task                                                      | Notes                                 | Done |
| --- | --------------------------------------------------------- | ------------------------------------- | ---- |
| 1   | Create Hetzner project                                    | Name: `huybrechts-family`             | [ ]  |
| 2   | Provision CPX31 VPS (Falkenstein or Nuremberg)            | 4 vCPU, 8 GB RAM, 160 GB SSD          | [ ]  |
| 3   | Provision BX11 Storage Box (1 TB)                         | Same region as VPS                    | [ ]  |
| 4   | Add SSH key to VPS                                        | Key from admin's workstation          | [ ]  |
| 5   | Run `strata` bootstrap against `haven` config             | OS hardening, Docker, UFW, Fail2Ban   | [ ]  |
| 6   | Deploy Caddy (reverse proxy + auto-TLS)                   | Subdomain routing config in `haven`   | [ ]  |
| 7   | Deploy Authentik (SSO/2FA)                                | OIDC provider; create admin account   | [ ]  |
| 8   | Deploy Vaultwarden                                        | Behind Caddy + Authentik SSO          | [ ]  |
| 9   | Deploy Infisical                                          | Behind Caddy + Authentik (admin only) | [ ]  |
| 10  | Deploy Immich                                             | Behind Caddy + Authentik SSO          | [ ]  |
| 11  | Configure BorgBackup cron (daily → Storage Box)           | Encryption key stored in Vaultwarden  | [ ]  |
| 12  | Configure Gatus health checks                             | Per-service endpoints                 | [ ]  |
| 13  | Register Healthchecks.io dead-man's switch for BorgBackup | Alerts if backup misses schedule      | [ ]  |
| 14  | Test restore from BorgBackup                              | Validate full cycle works             | [ ]  |

### DNS for VPS subdomains (at INWX)

Add A/CNAME records pointing to VPS IP:

```ascii
photos.huybrechts.xyz    → A → <VPS_IP>
vault.huybrechts.xyz     → A → <VPS_IP>
secrets.huybrechts.xyz   → A → <VPS_IP>
auth.huybrechts.xyz      → A → <VPS_IP>
status.huybrechts.xyz    → A → <VPS_IP>
```

> These records can be created immediately after domain transfer — they don't affect email.

---

## Phase 3 — Provision Infomaniak kSuite

| #   | Task                                                                | Notes                                              | Done |
| --- | ------------------------------------------------------------------- | -------------------------------------------------- | ---- |
| 1   | Purchase kSuite plan (5 users, kDrive 3 TB+)                        | Swiss data residency                               | [ ]  |
| 2   | Add primary domain `huybrechts.xyz` to kSuite                       | Verify ownership via DNS TXT record at INWX        | [ ]  |
| 3   | Add alias domains: `huybrechts.dev`, `meeus.family`, `alderwyn.xyz` | Each verified via TXT                              | [ ]  |
| 4   | Create 5 mailboxes on `huybrechts.xyz`                              | One per family member                              | [ ]  |
| 5   | Configure aliases for each user across alias domains                | e.g. `user@huybrechts.dev` → `user@huybrechts.xyz` | [ ]  |
| 6   | Create distribution group `family@huybrechts.xyz`                   | Members: all 5 mailboxes                           | [ ]  |
| 7   | Configure child mail forwarding rules                               | Each child → copy to both parents                  | [ ]  |
| 8   | Generate DKIM keys per domain in kSuite                             | Infomaniak provides the DNS records                | [ ]  |
| 9   | **Do NOT switch MX yet** — kSuite is ready but not receiving mail   | Parallel run preparation                           | [ ]  |

---

## Phase 4 — Data migration (parallel period)

> During this phase, Google Workspace is still active and receiving mail. kSuite is provisioned but MX is not switched.

### 4.1 Email history import

| #   | Task                                             | Notes                                                         | Done |
| --- | ------------------------------------------------ | ------------------------------------------------------------- | ---- |
| 1   | Use Infomaniak's IMAP migration tool             | Connects to Gmail IMAP, pulls all mail                        | [ ]  |
| 2   | Alternative: import MBOX via `imapsync`          | `imapsync --host1 imap.gmail.com --host2 mail.infomaniak.com` | [ ]  |
| 3   | Verify folder structure and message counts match | Spot-check sent, inbox, labels                                | [ ]  |
| 4   | Repeat for all 3 existing users                  | 2 new users have no history to migrate                        | [ ]  |

### 4.2 Contacts & Calendar

| #   | Task                                                        | Notes                      | Done |
| --- | ----------------------------------------------------------- | -------------------------- | ---- |
| 1   | Import vCard files into kSuite Contacts (per user)          | kSuite → Contacts → Import | [ ]  |
| 2   | Import ICS files into kSuite Calendar (per user)            | kSuite → Calendar → Import | [ ]  |
| 3   | Verify shared calendars and contact groups appear correctly |                            | [ ]  |

### 4.3 Files (Google Drive → kDrive)

| #   | Task                                                   | Notes                                          | Done |
| --- | ------------------------------------------------------ | ---------------------------------------------- | ---- |
| 1   | Install kDrive desktop client on admin machine         |                                                | [ ]  |
| 2   | Upload Google Drive export to kDrive                   | Drag-and-drop or sync folder                   | [ ]  |
| 3   | Set up shared folder structure for family              | Replicate Team Drives as kDrive shared folders | [ ]  |
| 4   | Verify file counts, folder structure, document formats | Google Docs → DOCX/XLSX (via Takeout)          | [ ]  |
| 5   | Install kDrive on family devices (mobile + desktop)    |                                                | [ ]  |

### 4.4 Photos (Google Photos → Immich)

| #   | Task                                          | Notes                              | Done |
| --- | --------------------------------------------- | ---------------------------------- | ---- |
| 1   | Upload Google Takeout photos export to Immich | Web UI bulk upload or CLI          | [ ]  |
| 2   | Verify albums, dates, metadata preserved      |                                    | [ ]  |
| 3   | Install Immich mobile app on family phones    | Enable auto-upload                 | [ ]  |
| 4   | Confirm face recognition indexing completes   | May take hours for large libraries | [ ]  |

### 4.5 Passwords (Bitwarden → Vaultwarden)

| #   | Task                                                 | Notes                                 | Done |
| --- | ---------------------------------------------------- | ------------------------------------- | ---- |
| 1   | Import Bitwarden JSON export into Vaultwarden        | Admin panel or personal vault import  | [ ]  |
| 2   | Create all 5 user accounts in Vaultwarden            | Via Authentik SSO or direct invite    | [ ]  |
| 3   | Set up Collections (Family / Dev / CI-Infra)         | Match current Bitwarden org structure | [ ]  |
| 4   | Install/reconfigure Bitwarden clients on all devices | Point to `vault.huybrechts.xyz`       | [ ]  |
| 5   | Verify all entries accessible and autofill works     |                                       | [ ]  |
| 6   | **Keep Bitwarden Team active until fully validated** | Cancel only after 2-week soak         | [ ]  |

### 4.6 Secrets (→ Infisical)

| #   | Task                                                          | Notes                                      | Done |
| --- | ------------------------------------------------------------- | ------------------------------------------ | ---- |
| 1   | Seed Infisical with all service credentials                   | API keys, DB passwords, tokens             | [ ]  |
| 2   | Create environments (production, staging)                     |                                            | [ ]  |
| 3   | Create projects per app                                       |                                            | [ ]  |
| 4   | Update Docker Compose services to pull secrets from Infisical | Via CLI/SDK env injection                  | [ ]  |
| 5   | Remove any hardcoded secrets from `haven` repo                | Verify git history doesn't contain secrets | [ ]  |

---

## Phase 5 — DNS cutover (MX switch)

> **This is the critical cutover point.** After this, mail flows to kSuite. Plan for a low-traffic window (evening/weekend).

### 5.1 Pre-cutover checklist

- [ ] All email history imported and verified in kSuite
- [ ] Contacts and calendars imported
- [ ] kSuite DKIM keys generated and ready to add to DNS
- [ ] All 5 mailboxes active and accessible
- [ ] Forwarding rules configured (child → parents)
- [ ] Family notified of the switch and timeline
- [ ] Rollback plan documented (revert MX to Google within 5 min)

### 5.2 DNS record changes at INWX

For **each domain** (`huybrechts.xyz`, `huybrechts.dev`, `meeus.family`, `alderwyn.xyz`):

| #   | Record type   | Action                                       | Value                                                     |
| --- | ------------- | -------------------------------------------- | --------------------------------------------------------- |
| 1   | MX            | Replace Google MX records with Infomaniak MX | `mx.infomaniak.com` (check exact values in kSuite panel)  |
| 2   | TXT (SPF)     | Replace Google SPF with Infomaniak SPF       | `v=spf1 include:spf.infomaniak.ch ~all`                   |
| 3   | TXT (DKIM)    | Add DKIM record from kSuite                  | Selector + public key provided by Infomaniak              |
| 4   | TXT (DMARC)   | Add/update DMARC                             | `v=DMARC1; p=quarantine; rua=mailto:dmarc@huybrechts.xyz` |
| 5   | TXT (MTA-STS) | Add if supported                             | Optional; enhances TLS enforcement                        |

> **TTL strategy:** 24–48h before cutover, lower TTL on MX/TXT records to 300s (5 min). This ensures fast rollback if needed. After stable for 1 week, raise TTL back to 3600s.

### 5.3 Execute cutover

| #   | Task                                                    | Notes                                            | Done |
| --- | ------------------------------------------------------- | ------------------------------------------------ | ---- |
| 1   | Lower TTL to 300s on MX/SPF/DKIM records                | Do this 48h before cutover                       | [ ]  |
| 2   | Switch MX records for all 4 domains                     | Point to Infomaniak                              | [ ]  |
| 3   | Update SPF records                                      | Include Infomaniak                               | [ ]  |
| 4   | Add DKIM records                                        | Per-domain keys from kSuite                      | [ ]  |
| 5   | Add/update DMARC records                                | Start with `p=none` for monitoring, then tighten | [ ]  |
| 6   | Send test emails from external accounts to each mailbox | Verify delivery                                  | [ ]  |
| 7   | Send test emails FROM each kSuite mailbox               | Verify outbound + SPF/DKIM pass                  | [ ]  |
| 8   | Check headers of received test emails                   | Confirm DKIM=pass, SPF=pass, DMARC=pass          | [ ]  |
| 9   | Verify forwarding rules work (child → parents)          | Send to child, confirm parents receive copy      | [ ]  |
| 10  | Verify `family@huybrechts.xyz` group delivers to all 5  |                                                  | [ ]  |
| 11  | Verify alias domains deliver to primary mailboxes       | Send to `user@huybrechts.dev` etc.               | [ ]  |
| 12  | Monitor bounce/error logs in kSuite for 24h             |                                                  | [ ]  |

### 5.4 Rollback (if needed)

If critical issues within first 24h:

1. Revert MX records at INWX to Google (`aspmx.l.google.com` etc.)
2. Revert SPF to Google include
3. Wait for TTL propagation (5 min if lowered beforehand)
4. Investigate and fix before retrying

---

## Phase 6 — Client configuration (family devices)

| #   | Task                                    | Device                | Notes                                                | Done |
| --- | --------------------------------------- | --------------------- | ---------------------------------------------------- | ---- |
| 1   | Configure kSuite email on iPhones/iPads | iOS                   | IMAP/SMTP or ActiveSync; autodiscovery should work   | [ ]  |
| 2   | Configure kSuite email on desktops      | Thunderbird / Outlook | IMAP + SMTP settings                                 | [ ]  |
| 3   | Set up CalDAV sync on all devices       | iOS + desktop         | kSuite provides CalDAV URL                           | [ ]  |
| 4   | Set up CardDAV sync on all devices      | iOS + desktop         | kSuite provides CardDAV URL                          | [ ]  |
| 5   | Install kDrive app on phones            | iOS / Android         | Sign in with kSuite account                          | [ ]  |
| 6   | Install kDrive desktop sync (if wanted) | macOS / Windows       | Optional — web access always available               | [ ]  |
| 7   | Install Immich app on phones            | iOS / Android         | Point to `photos.huybrechts.xyz`; enable auto-upload | [ ]  |
| 8   | Reconfigure Bitwarden apps              | All devices           | Change server URL to `vault.huybrechts.xyz`          | [ ]  |
| 9   | Enrol all users in Authentik 2FA        | All                   | TOTP or WebAuthn (security key)                      | [ ]  |

---

## Phase 7 — Decommission old services

> **Only after 2-week soak period with no issues.**

| #   | Task                                        | Notes                                           | Done |
| --- | ------------------------------------------- | ----------------------------------------------- | ---- |
| 1   | Disable Google Workspace mail delivery      | Ensure no straggler mail                        | [ ]  |
| 2   | Final Google Takeout export (safety backup) | Store on kDrive or VPS                          | [ ]  |
| 3   | Cancel Google Workspace subscription        | End billing                                     | [ ]  |
| 4   | Cancel Bitwarden Team subscription          | After Vaultwarden validated for 2+ weeks        | [ ]  |
| 5   | Decommission Kamatera VPS                   | After all workloads confirmed on Hetzner        | [ ]  |
| 6   | Let `theorderoftheblacklizard.be` expire    | Do not renew at current registrar               | [ ]  |
| 7   | Remove old DNS records no longer needed     | Clean up at previous registrar                  | [ ]  |
| 8   | Document final state                        | Update hosting-design.md with "migrated" status | [ ]  |

---

## Phase 8 — Post-migration hardening

| #   | Task                                                     | Notes                                               | Done |
| --- | -------------------------------------------------------- | --------------------------------------------------- | ---- |
| 1   | Raise DNS TTL back to 3600s                              | After 1 week stable                                 | [ ]  |
| 2   | Tighten DMARC policy to `p=quarantine` → then `p=reject` | After 2-4 weeks monitoring `rua` reports            | [ ]  |
| 3   | Test BorgBackup restore end-to-end                       | Full service recovery drill                         | [ ]  |
| 4   | Set up UptimeRobot external monitoring                   | Public endpoints: mail, vault, photos, auth         | [ ]  |
| 5   | Create runbook for common admin tasks                    | Password resets, new alias, backup restore          | [ ]  |
| 6   | Share emergency access credentials with trusted person   | Sealed envelope or shared Vaultwarden emergency kit | [ ]  |
| 7   | Schedule monthly maintenance window                      | Image updates, backup test, cert check              | [ ]  |

---

## Timeline estimate

| Phase                         | Duration           | Can overlap with |
| ----------------------------- | ------------------ | ---------------- |
| Phase 0 — Preparation         | 1–2 days           | —                |
| Phase 1 — Domain transfer     | 5–7 days (waiting) | Phase 2          |
| Phase 2 — VPS provisioning    | 1–2 days           | Phase 1          |
| Phase 3 — kSuite provisioning | 1 day              | Phase 1, 2       |
| Phase 4 — Data migration      | 2–3 days           | After Phase 2+3  |
| Phase 5 — DNS cutover         | 1 evening          | After Phase 4    |
| Phase 6 — Client config       | 1–2 days           | After Phase 5    |
| Phase 7 — Decommission        | After 2-week soak  | —                |
| Phase 8 — Hardening           | 1 day + ongoing    | After Phase 5    |

**Total elapsed: ~3–4 weeks** (most time is waiting for domain transfers and the soak period).

---

*Back to: [hosting-design.md](hosting-design.md)*
