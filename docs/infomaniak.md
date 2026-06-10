# Infomaniak and KSuite

[Back to Guide](./GUIDE.md#infomaniak)

## Overview

Infomaniak is a Swiss hosting provider offering email hosting and other services. KSuite is their email hosting product, which we will use for our email needs.

kSuite is the family collaboration platform for haven. It replaces Google Workspace for email, calendar, contacts, and cloud storage. It runs entirely on Infomaniak infrastructure. No self-hosted components are involved.

**Authentication:** kSuite uses Infomaniak's own identity system. External SSO (Authentik) is not supported. Each family member gets their own Infomaniak account and manages MFA natively.

**Automation:** kSuite has no Terraform/Ansible provider. Configuration is done manually via the Infomaniak Manager.

**SMTP:** kSuite provides an SMTP server for sending emails. We will configure Authentik to use this SMTP server for password resets and notifications.

| Setting  | Value                      | Source                                     |
| -------- | -------------------------- | ------------------------------------------ |
| Host     | `mail.infomaniak.com`      | Module definition                          |
| Port     | `587` (STARTTLS)           | Module definition                          |
| Username | SMTP account               | GitHub Secret: `AUTHENTIK_EMAIL__USERNAME` |
| Password | App password               | GitHub Secret: `AUTHENTIK_EMAIL__PASSWORD` |
| From     | `authentik@huybrechts.xyz` | Module definition                          |

## Organization Account

### Purchase kSuite

1. Log in to [manager.infomaniak.com](https://manager.infomaniak.com)
2. Navigate to **kSuite** → **Order**
3. Select plan: **5 users, kDrive 3 TB+** (or higher if needed)
4. Complete purchase and payment

### Enable MFA on the admin account

> ⚠️ Do this before creating any users or touching DNS.

1. Manager → top-right avatar → **Security**
2. Enable **Two-factor authentication** (TOTP)
3. Scan QR code with authenticator app
4. Store backup codes in Vaultwarden under "Infomaniak Admin MFA recovery"

## Email Domains

### Add and verify domains

Add each domain to kSuite. Infomaniak will provide a TXT record for ownership verification.

| Domain           |
| ---------------- |
| `huybrechts.xyz` |
| `huybrechts.dev` |
| `alderwyn.xyz`   |

**Steps (repeat per domain):**

1. Manager → kSuite → **Domains** → Add domain
2. Enter domain name → confirm
3. Copy the TXT verification record shown by kSuite
4. Add the TXT record at INWX (DNS → nameserver record)
5. Click **Verify** in kSuite — propagation can take up to 15 min
6. Mark as verified above once complete

**Set primary domain:**

Set `huybrechts.xyz` as the primary domain for mailboxes. The other two are alias domains —
they can receive mail but mailboxes live on the primary.

### DKIM configuration

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

## Mailboxes

### Create mailboxes

| Mailbox                  | Display name | Family member | Mailbox active | Notes |
| ------------------------ | ------------ | ------------- | -------------- | ----- |
| `vincent@huybrechts.xyz` | Vincent      |               | [ ]            |       |
| `spouse@huybrechts.xyz`  | Spouse       |               | [ ]            |       |
| `child1@huybrechts.xyz`  | Child1       |               | [ ]            |       |
| `child2@huybrechts.xyz`  | Child2       |               | [ ]            |       |
| `child3@huybrechts.xyz`  | Child3       |               | [ ]            |       |

Create one mailbox per family member on `huybrechts.xyz`.

1. Manager → kSuite → **Users** → Add user
2. Set email, display name, and initial password (or send invite)
3. Assign the appropriate kSuite licence

> **Special case — spouse:** She keeps her free Gmail account and does not want a kSuite mailbox
> initially. Create her kSuite user account **without assigning a mailbox licence** — she gets kDrive, kCalendar, and kContacts immediately.
>
> Options for later:
>
> - **Deferred mailbox:** Assign the mailbox licence when she's ready. Existing kDrive/calendar
>   data stays in place — nothing to migrate.
> - **Soft transition (recommended):** Create the kSuite mailbox now and configure it to
>   **forward all inbound mail to her Gmail** automatically. She keeps her current Gmail workflow unchanged.
>   When she's ready to fully switch, remove the forward rule.
>   Configure: Manager → kSuite → select user → Filters / Forwarding → add forward to Gmail address.

### Configure child mail forwarding

Children's inbound mail should be automatically forwarded to both parents until they are old enough to manage their own mailboxes. Set up forwarding rules for each child mailbox to forward all mail to both parents.

Per child user: Manager → kSuite → select user → **Filters / Forwarding** → add forward rule

| Child mailbox           | Forward to      | Configured |
| ----------------------- | --------------- | ---------- |
| `child1@huybrechts.xyz` | Vincent, Spouse | [ ]        |
| `child2@huybrechts.xyz` | Vincent, Spouse | [ ]        |
| `child3@huybrechts.xyz` | Vincent, Spouse | [ ]        |

### Configure Extra Mailboxes

Create additional mailboxes for shared addresses. These can be used for shared communication and can be accessed by multiple family members.

| Extra mailbox               | Access for | Configured |
| --------------------------- | ---------- | ---------- |
| `admin@huybrechts.xyz`      | Vincent    | [ ]        |
| `postmaster@huybrechts.xyz` | Vincent    | [ ]        |

### Configure Aliases

Add aliases per user so mail sent to any domain reaches the right mailbox.

> Example: `vincent@huybrechts.dev` and `vincent@alderwyn.xyz` both alias to `vincent@huybrechts.xyz`.

Per user: Manager → kSuite → select user → **Aliases** → Add alias

### Configure Redirections

Redirections allow you to automatically forward emails from one address to another within your domain.

| Extra mailbox                | Redirects to    | Configured |
| ---------------------------- | --------------- | ---------- |
| `family@huybrechts.xyz`      | Vincent, Spouse | [ ]        |
| `boekhouding@huybrechts.xyz` | Vincent, Spouse | [ ]        |
| `webmaster@huybrechts.xyz`   | Vincent         | [ ]        |

### MFA for family users

kSuite does not support enforced MFA from the admin panel at the individual account level on all plans. Recommended approach:

1. Instruct each family member to enable TOTP when they first log in:
   Manager → avatar → Security → Two-factor authentication
2. Verify with each member that MFA is active before the DNS cutover
3. Store backup codes in Vaultwarden per user

| User                     | MFA enabled | Backup codes stored |
| ------------------------ | ----------- | ------------------- |
| `vincent@huybrechts.xyz` | [ ]         | [ ]                 |
| `spouse@huybrechts.xyz`  | [ ]         | [ ]                 |
| `child1@huybrechts.xyz`  | [ ]         | [ ]                 |
| `child2@huybrechts.xyz`  | [ ]         | [ ]                 |
| `child3@huybrechts.xyz`  | [ ]         | [ ]                 |

## DNS cutover (MX switch)

> **Prerequisite:** All items in sections 3–6 must be complete. Warn the family 24h in advance.
> Lower DNS TTL to 300s at INWX at least 48h before the cutover window.

### MX records

Replace the existing Google MX records with Infomaniak's values for all 3 domains.

**Infomaniak MX records** (verify exact values from Manager → kSuite → Domains → DNS):

```data
MX priority / host:  ___________  (from kSuite panel — fill before cutover)
```

### SPF record

Replace the existing SPF TXT record on all 3 domains:

```dns
v=spf1 include:spf.infomaniak.ch ~all
```

> Remove the old Google SPF include (`include:_spf.google.com`) at the same time.

### DMARC record

Add a DMARC record (start with `p=none` — tighten after soak, see section 9):

```dns
v=DMARC1; p=none; rua=mailto:dmarc@huybrechts.xyz
```

### Cutover checklist

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

## Infomaniak Mail Server for Services

Required for password resets and notification emails. The mail server is provided by Infomaniak as part of the domain registration. You need to create an email account (e.g. `admin@huybrechts.xyz`).

The SMTP configuration is already prepared in the module definition of Strata. You just need to create the email account and generate an app password in Infomaniak, then add those credentials as GitHub Secrets for the deployment workflow to use.

Create an app password in Infomaniak:

> Manager → kSuite Mail → mailbox → Security → Application passwords → generate one for "Authentik SMTP"

- Add the configuration values to the Strata module definition (`mod-authentik.yaml`)
- Add the secrets to GitHub Environment Secrets (production)
