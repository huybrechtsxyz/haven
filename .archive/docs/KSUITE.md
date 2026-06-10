# kSuite Configuration Guide

> How to provision and configure Infomaniak kSuite as the haven family collaboration platform.

**Provider:** [Infomaniak](https://manager.infomaniak.com)  
**Services:** kMail · kDrive · kCalendar · kContacts  
**Primary domain:** `huybrechts.xyz`  
**Alias domains:** `huybrechts.dev` · `alderwyn.xyz`

---

## Overview

kSuite is the family collaboration platform for haven. It replaces Google Workspace for email,
calendar, contacts, and cloud storage. It runs entirely on Infomaniak infrastructure — no
self-hosted components are involved.

**Authentication:** kSuite uses Infomaniak's own identity system. External SSO (Authentik) is
not supported. Each family member gets their own Infomaniak account and manages MFA natively.

**Automation:** kSuite has no Terraform/Ansible provider. Configuration is done manually via
the Infomaniak Manager. DNS records at INWX will later be managed via `strata` config once
DNS support is available.

---

## 1. Account & plan

### 1.1 Purchase kSuite

1. Log in to [manager.infomaniak.com](https://manager.infomaniak.com) with `vincent@huybrechts.xyz`
2. Navigate to **kSuite** → **Order**
3. Select plan: **5 users, kDrive 3 TB+** (or higher if needed)
4. Note plan details:

```data
Plan:       ___________
Cost:       ___________  /month
Start date: ___________
```

### 1.2 Enable MFA on the admin account

> ⚠️ Do this before creating any users or touching DNS.

1. Manager → top-right avatar → **Security**
2. Enable **Two-factor authentication** (TOTP)
3. Scan QR code with authenticator app
4. Store backup codes in Vaultwarden under "Infomaniak Admin MFA recovery"

---

## 2. Domains

### 2.1 Add and verify domains

Add each domain to kSuite. Infomaniak will provide a TXT record for ownership verification.

| Domain           | Verification TXT record | Verified |
| ---------------- | ----------------------- | -------- |
| `huybrechts.xyz` |                         | [ ]      |
| `huybrechts.dev` |                         | [ ]      |
| `alderwyn.xyz`   |                         | [ ]      |

**Steps (repeat per domain):**

1. Manager → kSuite → **Domains** → Add domain
2. Enter domain name → confirm
3. Copy the TXT verification record shown by kSuite
4. Add the TXT record at INWX (DNS → nameserver record)
5. Click **Verify** in kSuite — propagation can take up to 15 min
6. Mark as verified above once complete

### 2.2 Set primary domain

Set `huybrechts.xyz` as the primary domain for mailboxes. The other two are alias domains —
they can receive mail but mailboxes live on the primary.

---

## 3. Mailboxes

### 3.1 Create mailboxes

Create one mailbox per family member on `huybrechts.xyz`.

1. Manager → kSuite → **Users** → Add user
2. Set email, display name, and initial password (or send invite)
3. Assign the appropriate kSuite licence

> **Special case — spouse:** She keeps her free Gmail account and does not want a kSuite mailbox
> initially. Create her kSuite user account **without assigning a mailbox licence** — she gets
> kDrive, kCalendar, and kContacts immediately. Options for later:
>
> - **Deferred mailbox:** Assign the mailbox licence when she's ready. Existing kDrive/calendar
>   data stays in place — nothing to migrate.
> - **Soft transition (recommended):** Create the kSuite mailbox now and configure it to
>   **forward all inbound mail to her Gmail** automatically. She keeps her current Gmail workflow
>   unchanged. When she's ready to fully switch, remove the forward rule.
>   Configure: Manager → kSuite → select user → Filters / Forwarding → add forward to Gmail address.

| Mailbox           | Display name | Family member | Mailbox active | Notes                             |
| ----------------- | ------------ | ------------- | -------------- | --------------------------------- |
| `@huybrechts.xyz` |              |               | [ ]            |                                   |
| `@huybrechts.xyz` |              |               | [ ]            |                                   |
| `@huybrechts.xyz` |              |               | [ ]            |                                   |
| `@huybrechts.xyz` |              |               | [ ]            |                                   |
| `@huybrechts.xyz` |              | spouse        | deferred       | forwards to Gmail in the meantime |

### 3.2 Configure aliases

Add aliases per user so mail sent to any domain reaches the right mailbox.

> Example: `vincent@huybrechts.dev` and `vincent@alderwyn.xyz` both alias to `vincent@huybrechts.xyz`.

Per user: Manager → kSuite → select user → **Aliases** → Add alias

### 3.3 Configure child mail forwarding

Children's inbound mail should be automatically forwarded to both parents.

Per child user: Manager → kSuite → select user → **Filters / Forwarding** → add forward rule

| Child mailbox | Forward to | Configured |
| ------------- | ---------- | ---------- |
|               |            | [ ]        |
|               |            | [ ]        |

---

## 4. Groups

### 4.1 Create family group

1. Manager → kSuite → **Groups** → Create group
2. Name: `family`
3. Address: `family@huybrechts.xyz`
4. Add all 5 family members as members

### 4.2 Additional groups

Create extra groups as needed:

| Group address           | Members | Purpose          |
| ----------------------- | ------- | ---------------- |
| `family@huybrechts.xyz` | All 5   | Family broadcast |
|                         |         |                  |

admin@huybrechts.xyz
family
 Accountancy <boekhouding@huybrechts.xyz
 Family <family@huybrechts.xyz>

 
---

## 5. MFA for family users

kSuite does not support enforced MFA from the admin panel at the individual account level on all
plans. Recommended approach:

1. Instruct each family member to enable TOTP when they first log in:
   Manager → avatar → Security → Two-factor authentication
2. Verify with each member that MFA is active before the DNS cutover
3. Store backup codes in Vaultwarden per user

| User | MFA enabled | Backup codes stored |
| ---- | ----------- | ------------------- |
|      | [ ]         | [ ]                 |
|      | [ ]         | [ ]                 |
|      | [ ]         | [ ]                 |
|      | [ ]         | [ ]                 |
|      | [ ]         | [ ]                 |

---

## 6. DKIM configuration

DKIM must be enabled per domain before the DNS cutover. kSuite generates the keys; you add
the TXT record at INWX.

**Steps (repeat per domain):**

1. Manager → kSuite → **Mail** → DKIM → select domain → Generate key
2. Copy the DKIM selector and full TXT record value
3. Add to INWX as a TXT record: `<selector>._domainkey.<domain>`

| Domain           | Selector | TXT record value (add at INWX) | Added |
| ---------------- | -------- | ------------------------------ | ----- |
| `huybrechts.xyz` |          |                                | [ ]   |
| `huybrechts.dev` |          |                                | [ ]   |
| `alderwyn.xyz`   |          |                                | [ ]   |

> ⚠️ Do not proceed to DNS cutover until DKIM TXT records are live and verified.  
> Test with: `Resolve-DnsName -Name "<selector>._domainkey.<domain>" -Type TXT`

---

## 7. DNS cutover (MX switch)

> **Prerequisite:** All items in sections 3–6 must be complete. Warn the family 24h in advance.
> Lower DNS TTL to 300s at INWX at least 48h before the cutover window.

### 7.1 MX records

Replace the existing Google MX records with Infomaniak's values for all 3 domains.

**Infomaniak MX records** (verify exact values from Manager → kSuite → Domains → DNS):

```data
MX priority / host:  ___________  (from kSuite panel — fill before cutover)
```

### 7.2 SPF record

Replace the existing SPF TXT record on all 3 domains:

```dns
v=spf1 include:spf.infomaniak.ch ~all
```

> Remove the old Google SPF include (`include:_spf.google.com`) at the same time.

### 7.3 DMARC record

Add a DMARC record (start with `p=none` — tighten after soak, see section 9):

```dns
v=DMARC1; p=none; rua=mailto:dmarc@huybrechts.xyz
```

### 7.4 Cutover checklist

Execute in order during a low-traffic window (evening or weekend):

| #   | Task                                           | Time / Notes        | Done |
| --- | ---------------------------------------------- | ------------------- | ---- |
| 1   | Switch MX for `huybrechts.xyz`                 |                     | [ ]  |
| 2   | Switch MX for `huybrechts.dev`                 |                     | [ ]  |
| 3   | Switch MX for `alderwyn.xyz`                   |                     | [ ]  |
| 4   | Update SPF for all 3 domains                   |                     | [ ]  |
| 5   | Add/verify DKIM records for all 3 domains      |                     | [ ]  |
| 6   | Add DMARC records for all 3 domains            |                     | [ ]  |
| 7   | Send test email (external → each mailbox)      | All 5 delivered?    | [ ]  |
| 8   | Send test email FROM each kSuite mailbox       | Delivered outbound? | [ ]  |
| 9   | Check headers: DKIM=pass, SPF=pass, DMARC=pass |                     | [ ]  |
| 10  | Test child → parent forwarding                 |                     | [ ]  |
| 11  | Test `family@huybrechts.xyz` group             | All 5 received?     | [ ]  |
| 12  | Monitor kSuite logs for 24h                    |                     | [ ]  |

### 7.5 Rollback

If a critical issue appears within 24h of cutover:

1. Revert MX to Google (`aspmx.l.google.com` priority 1, `alt1–4.aspmx.l.google.com` priority 5/10) at INWX for all 3 domains
2. Revert SPF to `v=spf1 include:_spf.google.com ~all`
3. Wait ~5 min for propagation (TTL is 300s)
4. Note the issue below and investigate before retrying:

```data
Issue: ___________
```

---

## 8. Client configuration

### 8.1 Connection settings

Retrieve exact values from Manager → kSuite → **Connection settings**:

```data
IMAP server:    ___________   Port: 993  (SSL/TLS)
SMTP server:    ___________   Port: 465  (SSL/TLS) or 587 (STARTTLS)
CalDAV URL:     ___________
CardDAV URL:    ___________
ActiveSync URL: ___________
```

### 8.2 Configure devices

For each device, configure email (IMAP/SMTP), calendar (CalDAV), contacts (CardDAV), and
install the kDrive desktop or mobile app.

| Device | Owner | Email | CalDAV | CardDAV | kDrive app | Done |
| ------ | ----- | ----- | ------ | ------- | ---------- | ---- |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |
|        |       | [ ]   | [ ]    | [ ]     | [ ]        | [ ]  |

> **kDrive desktop clients:** [infomaniak.com/en/kdrive/apps](https://www.infomaniak.com/en/kdrive/apps)  
> **kMail mobile app (iOS/Android):** search "kMail Infomaniak" in the app store

---

## 9. Post-cutover hardening

Execute after a 2-week soak period with no reported mail issues:

| #   | Task                                                                  | Target               | Done |
| --- | --------------------------------------------------------------------- | -------------------- | ---- |
| 1   | Raise DNS TTL back to 3600s at INWX                                   | 1 week post-cutover  | [ ]  |
| 2   | Review DMARC `rua` reports at `dmarc@huybrechts.xyz`                  | Weekly               | [ ]  |
| 3   | Change DMARC `p=none` → `p=quarantine`                                | 2 weeks post-cutover | [ ]  |
| 4   | Change DMARC `p=quarantine` → `p=reject`                              | 4 weeks post-cutover | [ ]  |
| 5   | Set up monthly kSuite cold export (IMAP pull + CalDAV/CardDAV to VPS) |                      | [ ]  |
| 6   | Cancel Google Workspace after soak gate passes                        |                      | [ ]  |

---

## 10. kDrive — shared folder structure

Suggested shared folder layout in kDrive:

```
Family/
├── Documents/       ← shared family documents
├── Photos/          ← shared photo albums (pending Immich — Wave 2)
├── Finance/         ← budget, taxes, invoices
└── Admin/           ← contracts, insurance, passports

Personal/<name>/     ← individual personal space (per user, private)
```

Create shared folders and set permissions: kDrive → New folder → Share → add family members.

---

## Notes

- **MX records do not affect webmail or Workspace access.** Google Workspace remains fully
  accessible after the MX switch — existing data stays available until the subscription is
  cancelled. This allows parallel access during the data migration window.
- **kSuite does not integrate with Authentik.** Each user authenticates directly with
  Infomaniak. MFA is managed per-user in the Infomaniak account settings.
- **DNS automation:** INWX DNS record management will be handled via `strata` config once DNS
  support is available. Until then, all DNS changes are applied manually at INWX.
