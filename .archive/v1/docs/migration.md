# Haven Migration Guide

> Two-wave gradual migration from Google Workspace + Kamatera to Infomaniak kSuite + Hetzner VPS.
> For system architecture and design rationale, see **[design.md](design.md)** and **[architecture.md](architecture.md)**.

---

## Strategy

**Two-wave gradual migration.** Wave 1 migrates developer/infrastructure services (VPS, passwords, secrets, photos) while Google Workspace stays active. Wave 2 migrates email, files, calendar, and contacts to kSuite after Wave 1 is proven stable.

**Why gradual?** VPS services only affect the admin (low blast radius). Google Workspace email affects the whole family daily (highest risk, migrate last). Domains were transferred early; MX stays on Google until Wave 2 cutover.

### Accounts & Access

| Service         | URL                              | Username                 | Credentials stored                          |
| --------------- | -------------------------------- | ------------------------ | ------------------------------------------- |
| INWX            | <https://www.inwx.de>            | `vincent@huybrechts.xyz` | Bitwarden (migrate to Vaultwarden → Family) |
| Hetzner         | <https://console.hetzner.cloud>  | `vincent@huybrechts.xyz` | Bitwarden (migrate to Vaultwarden → Family) |
| Infomaniak      | <https://manager.infomaniak.com> | `vincent@huybrechts.xyz` | Vaultwarden → Family                        |
| Healthchecks.io | <https://healthchecks.io>        | `vincent@huybrechts.xyz` | Vaultwarden → Family                        |
| UptimeRobot     | <https://uptimerobot.com>        | `vincent@huybrechts.xyz` | Vaultwarden → Family                        |

---

## Wave 1 — Infrastructure & Developer Services

**Wave 1 status:** 🟡 In progress  
**Wave 1 started:** 2026-06-02  
**Wave 1 completed:** ___________

> Goal: Hetzner VPS fully operational, Kamatera decommissioned, Bitwarden Team replaced. Google Workspace untouched.

### Phase 1.1 — Domain transfer to INWX

**Status:** ✅ Complete — 2026-06-02

**Decisions:**

- `meeus.family` will **NOT** be transferred — renewal jumps to ~€52/yr from year 2. Let expire at Versio.
- `alderwyn.xyz` and `madebyjana.be` were registered via ClouDNS (backend: PDR Ltd.), **not** Versio. Both expired 30 June 2026 — contact ClouDNS support for EPP codes.
- Total domains transferred: **4** — `huybrechts.xyz`, `huybrechts.dev`, `alderwyn.xyz`, `madebyjana.be`

#### DNS snapshot before transfer (captured 2026-05-27)

**huybrechts.xyz** (was at Versio):

| Type | Name                             | Priority | Value                                            | TTL   |
| ---- | -------------------------------- | -------- | ------------------------------------------------ | ----- |
| A    | huybrechts.xyz                   |          | 185.237.97.232                                   | 3600  |
| A    | <www.huybrechts.xyz>             |          | 185.237.97.232                                   | 3600  |
| MX   | huybrechts.xyz                   | 1        | ASPMX.L.GOOGLE.COM                               | 14400 |
| MX   | huybrechts.xyz                   | 5        | ALT1.ASPMX.L.GOOGLE.COM                          | 14400 |
| MX   | huybrechts.xyz                   | 5        | ALT2.ASPMX.L.GOOGLE.COM                          | 14400 |
| MX   | huybrechts.xyz                   | 10       | ALT3.ASPMX.L.GOOGLE.COM                          | 14400 |
| MX   | huybrechts.xyz                   | 10       | ALT4.ASPMX.L.GOOGLE.COM                          | 14400 |
| TXT  | huybrechts.xyz                   |          | v=spf1 include:_spf.google.com ~all              | 14400 |
| TXT  | google._domainkey.huybrechts.xyz |          | v=DKIM1; k=rsa; p=MIIBIjAN… *(full key in INWX)* | 14400 |
| CAA  | huybrechts.xyz                   |          | 128 issue "letsencrypt.org"                      | 14400 |

**huybrechts.dev** (was at Versio):

| Type | Name           | Priority | Value                               | TTL   |
| ---- | -------------- | -------- | ----------------------------------- | ----- |
| A    | huybrechts.dev |          | 185.47.174.65                       | 3600  |
| MX   | huybrechts.dev | 1        | ASPMX.L.GOOGLE.COM                  | 14400 |
| MX   | huybrechts.dev | 5        | ALT1.ASPMX.L.GOOGLE.COM             | 14400 |
| MX   | huybrechts.dev | 5        | ALT2.ASPMX.L.GOOGLE.COM             | 14400 |
| MX   | huybrechts.dev | 10       | ALT3.ASPMX.L.GOOGLE.COM             | 14400 |
| MX   | huybrechts.dev | 10       | ALT4.ASPMX.L.GOOGLE.COM             | 14400 |
| TXT  | huybrechts.dev |          | v=spf1 a mx ip4:185.182.56.120 …    | 14400 |
| TXT  | huybrechts.dev |          | google-site-verification=bTxhh5aX4… | 14400 |
| CAA  | huybrechts.dev |          | 0 issue "letsencrypt.org"           | 3600  |

#### Transfer steps

| #     | Task                                                                     | Result / Notes                                                                                                                | Done |
| ----- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1     | Unlock `huybrechts.xyz` at Versio                                        | ✓ 2026-05-27                                                                                                                  | [x]  |
| 2     | Unlock `huybrechts.dev` at Versio                                        | ✓ 2026-05-27                                                                                                                  | [x]  |
| ~~3~~ | ~~Unlock `meeus.family` at Versio~~                                      | ✗ decommissioned                                                                                                              | —    |
| 4     | Contact ClouDNS — unlock `alderwyn.xyz` + `madebyjana.be`, get EPP codes | ✓ 2026-05-27 — tickets submitted                                                                                              | [x]  |
| 5     | Request EPP code for `huybrechts.xyz` at Versio                          | ✓ 2026-05-27                                                                                                                  | [x]  |
| 6     | Request EPP code for `huybrechts.dev` at Versio                          | ✓ 2026-05-27                                                                                                                  | [x]  |
| 7     | Receive EPP codes from ClouDNS                                           | `alderwyn.xyz` ✓ · `madebyjana.be` ✓ (.be uses DNS.be email confirmation, no EPP)                                             | [x]  |
| 8     | Initiate transfers at INWX                                               | All 4 started 2026-05-27                                                                                                      | [x]  |
| 9     | Approve confirmation emails                                              | ✓ 2026-06-01                                                                                                                  | [x]  |
| 10    | Confirm all 4 domains in INWX panel                                      | ✓ 2026-06-02 — NS switched to `ns1/ns2/ns3.inwx.de`                                                                           | [x]  |
| 11    | Recreate DNS records at INWX identically                                 | ✓ 2026-06-02 — MX/A/TXT/DKIM/CAA all added; DNSSEC not configured; transient validation error during NS propagation, resolved | [x]  |
| 12    | Enable WHOIS privacy                                                     | `alderwyn.xyz` ✓ · `huybrechts.xyz` ✓ · `huybrechts.dev` ✓ · `.be` does not support WHOIS privacy                             | [x]  |
| 13    | Send test email — verify mail still works                                | ✓ 2026-06-02 — test email received from work address                                                                          | [x]  |

#### Domain expiry dates after transfer

| Domain             | Expiry at INWX                     |
| ------------------ | ---------------------------------- |
| `huybrechts.xyz`   | 2027-10-04                         |
| `huybrechts.dev`   | *(fill in)*                        |
| `alderwyn.xyz`     | *(fill in from INWX panel)*        |
| `madebyjana.be`    | *(fill in)*                        |
| ~~`meeus.family`~~ | ✗ decommissioned — not transferred |

---

### Phase 1.2 — Provision Hetzner VPS + Storage Box

**Status:** 🟡 In progress

#### Steps

| #   | Task                                           | Result / Notes               | Done |
| --- | ---------------------------------------------- | ---------------------------- | ---- |
| 1   | Create Hetzner project `huybrechts-family`     |                              | [ ]  |
| 2   | Provision CX23 VPS (Core)                      | Region: ___________          | [ ]  |
| 3   | Provision BX11 Storage Box                     | Region: ___________          | [ ]  |
| 4   | Add SSH public key to VPS                      | Key fingerprint: ___________ | [ ]  |
| 5   | Create S3 buckets `photos`, `media`, `archive` | Provider/project: ________   | [ ]  |
| 6   | Configure replication S3 → Infomaniak kDrive   | Job/tool: ___________        | [ ]  |
| 7   | Run `strata` bootstrap                         | Completed: ___________       | [ ]  |
| 8   | Deploy Caddy                                   |                              | [ ]  |
| 9   | Verify Caddy HTTPS on VPS IP                   |                              | [ ]  |

#### Server details (fill in)

```
VPS IP:           ___.___.___.___ 
Storage Box host: ___________
Storage Box user: ___________
SSH key:          ~/.ssh/___________
```

#### DNS — add A records at INWX for VPS subdomains

| Subdomain                | Value      | Added |
| ------------------------ | ---------- | ----- |
| `auth.huybrechts.xyz`    | `<VPS_IP>` | [ ]   |
| `vault.huybrechts.xyz`   | `<VPS_IP>` | [ ]   |
| `secrets.huybrechts.xyz` | `<VPS_IP>` | [ ]   |
| `photos.huybrechts.xyz`  | `<VPS_IP>` | [ ]   |
| `status.huybrechts.xyz`  | `<VPS_IP>` | [ ]   |

---

### Phase 1.3 — Deploy Authentik (SSO)

**Status:** 🔴 Not started  
**URL:** <https://auth.huybrechts.xyz>

| #   | Task                                              | Result / Notes                     | Done |
| --- | ------------------------------------------------- | ---------------------------------- | ---- |
| 1   | Deploy Authentik via Docker Compose               |                                    | [ ]  |
| 2   | Create admin account                              | ⚠ Credentials in Vaultwarden → Dev | [ ]  |
| 3   | Enforce 2FA for all accounts (TOTP / WebAuthn)    |                                    | [ ]  |
| 4   | Create OIDC app for Vaultwarden                   | Client ID: ___________             | [ ]  |
| 5   | Create OIDC app for Immich                        | Client ID: ___________             | [ ]  |
| 6   | Create OIDC app for Infisical                     | Client ID: ___________             | [ ]  |
| 7   | Create user accounts for all 5 family members     |                                    | [ ]  |
| 8   | Test login flow (redirect + token exchange works) |                                    | [ ]  |

> ⚠ Store all OIDC client secrets in Infisical (once deployed) or Vaultwarden. Do not commit to git.

---

### Phase 1.4 — Deploy Vaultwarden (passwords)

**Status:** 🔴 Not started  
**URL:** <https://vault.huybrechts.xyz>

| #   | Task                                          | Result / Notes                | Done |
| --- | --------------------------------------------- | ----------------------------- | ---- |
| 1   | Deploy Vaultwarden via Docker Compose         |                               | [ ]  |
| 2   | Configure OIDC via Authentik                  |                               | [ ]  |
| 3   | Import Bitwarden JSON export                  | Items imported: ___________   | [ ]  |
| 4   | Create user accounts for all 5 family members |                               | [ ]  |
| 5   | Set up Collections: Family / Dev / CI-Infra   |                               | [ ]  |
| 6   | Reconfigure Bitwarden client on admin devices | Server: vault.huybrechts.xyz  | [ ]  |
| 7   | Verify autofill and all entries accessible    |                               | [ ]  |
| 8   | Roll out to family devices                    | Last device done: ___________ | [ ]  |
| 9   | Start 2-week soak period                      | Soak started: ___________     | [ ]  |
| 10  | Cancel Bitwarden Team after soak              | Cancelled: ___________        | [ ]  |

---

### Phase 1.5 — Deploy Infisical (secrets)

**Status:** 🔴 Not started  
**URL:** <https://secrets.huybrechts.xyz>

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

| #   | Task                                                            | Result / Notes               | Done |
| --- | --------------------------------------------------------------- | ---------------------------- | ---- |
| 1   | Deploy Immich via Docker Compose                                |                              | [ ]  |
| 2   | Configure OIDC login via Authentik                              |                              | [ ]  |
| 3   | Export Google Photos via Takeout (original quality, all users)  |                              | [ ]  |
| 4   | Upload photo library to Immich                                  | Photos imported: ___________ | [ ]  |
| 5   | Verify albums, dates, metadata preserved                        |                              | [ ]  |
| 6   | Install Immich mobile app on family phones (enable auto-upload) |                              | [ ]  |
| 7   | Confirm face recognition indexing completes                     |                              | [ ]  |

---

### Phase 1.7 — Backups & Monitoring

**Status:** 🔴 Not started

| #   | Task                                                                     | Result / Notes                | Done |
| --- | ------------------------------------------------------------------------ | ----------------------------- | ---- |
| 1   | Configure BorgBackup cron (daily → Storage Box)                          | Encryption key in Vaultwarden | [ ]  |
| 2   | Configure scheduled S3 replication (`photos`/`media`/`archive` → kDrive) | Tool/job: ___________         | [ ]  |
| 3   | Test full restore from BorgBackup                                        |                               | [ ]  |
| 4   | Test restore from kDrive copy back into S3                               |                               | [ ]  |
| 5   | Deploy Gatus health checks (per-service endpoints)                       |                               | [ ]  |
| 6   | Register Healthchecks.io dead-man's switch (backup alert)                |                               | [ ]  |
| 7   | Set up UptimeRobot for public endpoint monitoring                        |                               | [ ]  |

---

### Phase 1.8 — Decommission Kamatera + Bitwarden

> Only after all VPS services stable for 2+ weeks.

| #   | Task                                         | Result / Notes     | Done |
| --- | -------------------------------------------- | ------------------ | ---- |
| 1   | Verify no traffic/services still on Kamatera |                    | [ ]  |
| 2   | Final backup of Kamatera data                |                    | [ ]  |
| 3   | Decommission Kamatera VPS                    | Cancelled: _______ | [ ]  |
| 4   | Cancel Bitwarden Team subscription           | Cancelled: _______ | [ ]  |

#### Wave 1 cost impact

| Item removed     | Monthly saving |
| ---------------- | -------------- |
| Bitwarden Team   | ~€15/mo        |
| Kamatera VPS     | ~€20-40/mo     |
| **Total saving** | **~€35-55/mo** |

| Item added               | Monthly cost           |
| ------------------------ | ---------------------- |
| Hetzner CX23 VPS         | ~€4/mo                 |
| Forge S3 object storage  | TBD                    |
| Hetzner BX11 Storage Box | ~€4/mo                 |
| Domains (4 × INWX)       | ~€6.30/mo              |
| **Total new cost**       | **~€14/mo + S3 usage** |

> Google Workspace continues at ~€18/mo during Wave 1. Family experiences no disruption.

---

## Wave 2 — Email, Files & Collaboration (Google → kSuite)

> Start Wave 2 only after Wave 1 is stable for at least 2–4 weeks.

**Decision gate — all must be ✓ before starting Wave 2:**

- [ ] All VPS services stable for 2+ weeks (no unplanned downtime)
- [ ] BorgBackup tested and running daily
- [ ] Vaultwarden adopted by all family members
- [ ] Immich photo upload working on all phones
- [ ] Kamatera fully decommissioned
- [ ] Bitwarden Team cancelled

### Phase 2.1 — Preparation & exports

| #   | Task                                               | Notes | Done |
| --- | -------------------------------------------------- | ----- | ---- |
| 1   | Create Infomaniak account (admin)                  |       | [ ]  |
| 2   | Export Gmail (all 3 users) — MBOX via Takeout      |       | [ ]  |
| 3   | Export Google Contacts (all 3 users) — vCard .vcf  |       | [ ]  |
| 4   | Export Google Calendar (all 3 users) — ICS .ics    |       | [ ]  |
| 5   | Export Google Drive (all 3 users) — Takeout/rclone |       | [ ]  |
| 6   | Validate MBOX files (spot-check in Thunderbird)    | ✓     | [ ]  |
| 7   | Confirm vCard/ICS open correctly                   | ✓     | [ ]  |
| 8   | Confirm Drive export complete                      | ✓     | [ ]  |

### Phase 2.2 — Provision kSuite

**Status:** 🔴 Not started

| #     | Task                                                   | Result / Notes                 | Done |
| ----- | ------------------------------------------------------ | ------------------------------ | ---- |
| 1     | Purchase kSuite plan (5 users, kDrive 3 TB+)           | Plan: ___________ Cost: ___/mo | [ ]  |
| 2     | Add + verify `huybrechts.xyz`                          | Verified: ___________          | [ ]  |
| 3     | Add + verify `huybrechts.dev`                          | Verified: ___________          | [ ]  |
| 4     | Add + verify `alderwyn.xyz`                            | Verified: ___________          | [ ]  |
| ~~5~~ | ~~Add + verify `meeus.family`~~                        | ✗ decommissioned               | —    |
| 6     | Create 5 mailboxes on `huybrechts.xyz`                 |                                | [ ]  |
| 7     | Configure aliases across alias domains                 |                                | [ ]  |
| 8     | Create `family@huybrechts.xyz` group (all 5)           |                                | [ ]  |
| 9     | Configure child mail forwarding (child → both parents) |                                | [ ]  |
| 10    | Generate DKIM keys per domain in kSuite                | Note DNS records for Phase 2.4 | [ ]  |

#### kSuite mailboxes (fill in real names)

| Mailbox on `@huybrechts.xyz` | Family member | Aliases configured | Done |
| ---------------------------- | ------------- | ------------------ | ---- |
|                              |               |                    | [ ]  |
|                              |               |                    | [ ]  |
|                              |               |                    | [ ]  |
|                              |               |                    | [ ]  |
|                              |               |                    | [ ]  |

#### DKIM keys from kSuite (fill in before cutover)

| Domain           | DKIM selector | DNS TXT value |
| ---------------- | ------------- | ------------- |
| `huybrechts.xyz` |               |               |
| `huybrechts.dev` |               |               |
| `alderwyn.xyz`   |               |               |

---

### Phase 2.3 — Data migration (parallel period)

> Google still active. kSuite ready but MX **not** switched yet.

#### Email history

| #   | Task                                        | Result / Notes                 | Done |
| --- | ------------------------------------------- | ------------------------------ | ---- |
| 1   | Run Infomaniak IMAP migration tool (user 1) | Messages migrated: ___________ | [ ]  |
| 2   | Run Infomaniak IMAP migration tool (user 2) | Messages migrated: ___________ | [ ]  |
| 3   | Run Infomaniak IMAP migration tool (user 3) | Messages migrated: ___________ | [ ]  |
| 4   | Verify folder structure and message counts  |                                | [ ]  |

#### Contacts & Calendar

| #   | Task                                       | Result / Notes        | Done |
| --- | ------------------------------------------ | --------------------- | ---- |
| 1   | Import vCard into kSuite Contacts (user 1) | Contacts: ___________ | [ ]  |
| 2   | Import vCard into kSuite Contacts (user 2) | Contacts: ___________ | [ ]  |
| 3   | Import vCard into kSuite Contacts (user 3) | Contacts: ___________ | [ ]  |
| 4   | Import ICS into kSuite Calendar (user 1)   | Events: ___________   | [ ]  |
| 5   | Import ICS into kSuite Calendar (user 2)   | Events: ___________   | [ ]  |
| 6   | Import ICS into kSuite Calendar (user 3)   | Events: ___________   | [ ]  |
| 7   | Verify shared calendars and contact groups |                       | [ ]  |

#### Files (Google Drive → kDrive)

| #   | Task                                    | Result / Notes                | Done |
| --- | --------------------------------------- | ----------------------------- | ---- |
| 1   | Install kDrive desktop client           |                               | [ ]  |
| 2   | Upload Google Drive export to kDrive    | Size uploaded: ___________ GB | [ ]  |
| 3   | Set up shared folder structure          |                               | [ ]  |
| 4   | Verify file counts and document formats |                               | [ ]  |

---

### Phase 2.4 — DNS Cutover (MX switch)

**Cutover window planned:** ___________ (evening/weekend)

#### Pre-cutover checklist — all must be ✓ before proceeding

- [ ] All email history imported and verified in kSuite
- [ ] Contacts and calendars imported
- [ ] DKIM keys from kSuite recorded (Phase 2.2)
- [ ] All 5 mailboxes tested via kSuite webmail
- [ ] Forwarding rules verified (test email to child → parents received copy)
- [ ] `family@huybrechts.xyz` group tested
- [ ] Family notified of cutover window
- [ ] TTL lowered to 300s at INWX (48h before cutover)

#### DNS records to change at INWX (all 3 domains)

**MX** — replace Google entries with:

```
MX priority / host:  ___________  (from kSuite panel)
```

**SPF:**

```
v=spf1 include:spf.infomaniak.ch ~all
```

**DMARC (start with p=none):**

```
v=DMARC1; p=none; rua=mailto:dmarc@huybrechts.xyz
```

#### Execute cutover

| #     | Task                                           | Time / Notes           | Done |
| ----- | ---------------------------------------------- | ---------------------- | ---- |
| 1     | Switch MX for `huybrechts.xyz`                 | Time: ___________      | [ ]  |
| 2     | Switch MX for `huybrechts.dev`                 | Time: ___________      | [ ]  |
| 3     | Switch MX for `alderwyn.xyz`                   | Time: ___________      | [ ]  |
| ~~4~~ | ~~Switch MX for `meeus.family`~~               | ✗ decommissioned       | —    |
| 5     | Update SPF for all 3 domains                   |                        | [ ]  |
| 6     | Add DKIM records for all 3 domains             |                        | [ ]  |
| 7     | Add DMARC records for all 3 domains            |                        | [ ]  |
| 8     | Send test email (external → each mailbox)      |                        | [ ]  |
| 9     | Send test email FROM each kSuite mailbox       |                        | [ ]  |
| 10    | Check headers: DKIM=pass, SPF=pass, DMARC=pass |                        | [ ]  |
| 11    | Test child → parent forwarding                 |                        | [ ]  |
| 12    | Test `family@huybrechts.xyz` group             |                        | [ ]  |
| 13    | Monitor kSuite logs for 24h                    | No errors: ___________ | [ ]  |

#### Rollback (if critical issue within 24h)

1. Revert MX records to Google (`aspmx.l.google.com` etc.) at INWX
2. Revert SPF to Google include
3. Wait ~5 min (TTL at 300s)
4. Investigate and note issue: ___________

---

### Phase 2.5 — Client Configuration

**Status:** 🔴 Not started

#### kSuite connection settings (fill in from kSuite panel)

```
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

> Only after 2-week soak from MX cutover with no email issues.

#### Wave 2 soak gate

- [ ] Soak started: ___________
- [ ] No missed/bounced emails reported
- [ ] All family members receiving and sending normally
- [ ] Calendars and contacts syncing on all devices

#### Steps

| #   | Task                                       | Result / Notes              | Done |
| --- | ------------------------------------------ | --------------------------- | ---- |
| 1   | Verify no mail still going to Gmail        | Last straggler: ___________ | [ ]  |
| 2   | Final Google Takeout archive (safety copy) | Stored on: ___________      | [ ]  |
| 3   | Cancel Google Workspace                    | Cancelled: ___________      | [ ]  |
| 4   | Remove Google OAuth grants / app passwords |                             | [ ]  |

**Wave 2 complete:** ___________

---

### Phase 2.7 — Post-migration Hardening

| #   | Task                                                                  | Target date           | Done |
| --- | --------------------------------------------------------------------- | --------------------- | ---- |
| 1   | Raise DNS TTL back to 3600s (1 week after cutover)                    |                       | [ ]  |
| 2   | DMARC `p=none` → `p=quarantine` (after 2 weeks, review `rua` reports) |                       | [ ]  |
| 3   | DMARC `p=quarantine` → `p=reject` (after 4 weeks)                     |                       | [ ]  |
| 4   | Set up monthly kSuite cold export to VPS (IMAP + CalDAV/CardDAV pull) |                       | [ ]  |
| 5   | Write family runbook (password reset, add device, add alias)          |                       | [ ]  |
| 6   | Share emergency access credentials with trusted person                |                       | [ ]  |
| 7   | Schedule monthly maintenance window                                   | Day/time: ___________ | [ ]  |

---

## Migration Timeline

| Phase                      | Duration              | Notes                                          |
| -------------------------- | --------------------- | ---------------------------------------------- |
| **Wave 1**                 |                       |                                                |
| 1.1 — Domain transfer      | ✅ done                |                                                |
| 1.2 — VPS provisioning     | 1–2 days              | In progress                                    |
| 1.3 — Authentik            | 0.5 day               | After 1.2                                      |
| 1.4 — Vaultwarden          | 0.5 day               | After 1.3                                      |
| 1.5 — Infisical            | 0.5 day               | After 1.3                                      |
| 1.6 — Immich               | 1 day                 | After 1.3                                      |
| 1.7 — Backups & monitoring | 0.5 day               | After 1.2                                      |
| 1.8 — Decommission old     | After 2-week soak     |                                                |
| **Wave 1 total**           | ~3 weeks (incl. soak) |                                                |
| **Wave 2**                 |                       |                                                |
| 2.1 — Preparation          | 1–2 days              |                                                |
| 2.2 — kSuite provisioning  | 1 day                 | After 2.1                                      |
| 2.3 — Data migration       | 2–3 days              | After 2.2                                      |
| 2.4 — DNS cutover          | 1 evening             | After 2.3                                      |
| 2.5 — Client config        | 1–2 days              | After 2.4                                      |
| 2.6 — Decommission Google  | After 2-week soak     |                                                |
| 2.7 — Hardening            | Ongoing               | After 2.4                                      |
| **Wave 2 total**           | ~3 weeks (incl. soak) |                                                |
| **Total elapsed**          | **~6 weeks**          | Family disruption: Wave 2 cutover evening only |

---

## Final Cost Summary (fill in after Wave 2)

| Item                            | Cost        |
| ------------------------------- | ----------- |
| Infomaniak kSuite (actual plan) | €___/mo     |
| Hetzner CX23 VPS                | ~€4/mo      |
| Hetzner BX11 Storage Box        | ~€4/mo      |
| INWX domains (~€76/yr)          | ~€6.30/mo   |
| **Total**                       | **€___/mo** |
| **Previous spend**              | ~€58-81/mo  |
| **Saving**                      | **€___/mo** |
