# Huybrechts.xyz Platform

## Context & Constraints

- **Users:** family of 5 (5 mailboxes, shared storage, shared calendars/contacts).
- **Admin:** owner is comfortable with admin overhead for self-hosted apps (Nextcloud, photos, etc.).
- **Email:** email servers (MTA, spam filtering, deliverability, PTR, IP reputation) require significant ongoing ops — **email must be managed** (no self-hosted MTA).
- **Hosting preference:** EU/Swiss jurisdiction, strong privacy, DPA in place.
- **Simplicity:** fewer integrated systems preferred; self-hosted is fine for everything except email.
- **Domains:** one primary email domain; multiple secondary domains that forward to the primary.
- **Apps:** home-grown applications will need compute — a VPS or small Kubernetes cluster (k3s/k8s). Prefer EU VPS or managed K8s (Hetzner, Scaleway, OVH) and plan for container runtime, ingress, TLS and persistent storage.
- **Password manager:** Bitwarden paid Team account is currently in use. Decision: **migrate to Vaultwarden** (self-hosted Bitwarden-compatible server) on the VPS — same Firefox/iPhone client UX, saves ~€15/mo, vault data stays on EU infrastructure. Use Collections (Family / Dev / CI-Infra) to segment access. Requires solid VPS backup strategy (vault is critical infrastructure).
- **Secret management (app secrets):** home-grown apps, CI/CD pipelines and Terraform need a place to store API keys, DB passwords and service credentials. Options — pick one based on complexity:
  - **Bitwarden CLI → Vaultwarden** — zero extra cost; store secrets as vault items, retrieve with `bw get` in scripts. Good enough for simple setups (< ~20 secrets, no dynamic credentials).
  - **Infisical** (self-hosted) — modern open-source secrets platform; per-app/per-environment secret namespacing, CLI, SDK, Docker/k8s operator, audit log. Runs as a Docker container on the same VPS. Best choice once app count grows.
  - **HashiCorp Vault** — enterprise-grade, dynamic secrets, fine-grained policies. Overkill for a home setup unless running many apps or need dynamic DB credentials.

### Current monthly spend (baseline)

| Item                                         | Est. cost                       |
| -------------------------------------------- | ------------------------------- |
| Google Workspace (3 users, Business Starter) | ~€18/mo                         |
| Kamatera VPS                                 | ~€20-40/mo                      |
| 5 domains                                    | ~€5-8/mo                        |
| Bitwarden Team (current, to be replaced)     | ~€15/mo                         |
| Vaultwarden on VPS (target)                  | €0 (free, runs on existing VPS) |
| **Total current**                            | **~€58-81/mo**                  |

## Goal

Replace Google Workspace and Kamatera self-hosting with a privacy-focused, EU‑backed hosting solution that:

- Centralizes email on a single primary domain; secondary domains forwarded/aliased to it.
- Provides managed email (no self-hosted MTA) plus calendar, contacts, file sync, document editing, and photo management.
- Ensures EU/Swiss data residency, strong deliverability and privacy controls (SPF, DKIM, DMARC, MTA‑STS, TLS), 2FA, and encrypted backups.
- Provides EU compute (VPS or k3s) for home-grown applications alongside the collaboration stack.
- Keeps total cost comparable to current spend while covering 5 users instead of 3.

## Capabilities Needed

- **Email hosting (MTA + IMAP/SMTP):** reliable SMTP submission, IMAP/IMAPS access, per-mailbox quotas, authenticated submission and TLS.
- **Domain aliases & forwarding:** support for a single primary domain with multiple alias/forwarder domains; per-domain MX configuration and forwarding rules; optional catch‑all with spam controls.
- **Mailbox management & groups:** user provisioning, aliases, distribution lists, shared mailboxes, delegated access and role-based admin.
- **Webmail & client sync:** modern webmail UI plus CalDAV/CardDAV and ActiveSync support for mobile and desktop clients.
- **Calendar & contacts:** shared calendars, free/busy, delegation, ICS/vCard import/export and syncing.
- **File sync & collaboration:** Nextcloud or equivalent with sync clients, collaborative editors (OnlyOffice/Collabora) and file versioning.
- **Deliverability & DNS controls:** per-domain SPF, DKIM signing, DMARC (aggregate/forensic reports), MTA‑STS, TLS, PTR records and optional DNSSEC.
- **IP reputation & outbound strategy:** *(provider-managed when using a managed email service — verify PTR and shared IP reputation at signup)*
- **Security & anti-abuse:** spam/virus filtering, DKIM/DMARC enforcement, brute-force protection, RBL monitoring and per-mailbox rate limiting. *(core spam/AV managed by provider; ensure admin controls are exposed)*
- **Authentication & access control:** SSO/OAuth2/OIDC/LDAP/AD integration, `2FA` (TOTP/WebAuthn), strong password policies and audit logs.
- **Encryption & privacy:** TLS in transit, at-rest encryption, optional end-to-end (PGP/S/MIME) support, minimal logging and Data Processing Agreement (DPA).
- **Data residency & compliance:** EU hosting, DPA, retention policies, legal hold / eDiscovery support as required.
- **Migration tooling:** `imapsync`, `rclone`, Google Takeout workflows, incremental sync tooling, mailbox mapping and rollback/validation steps.
- **Backups & recovery:** automated encrypted backups for mail, databases and files; tested restore procedures and defined retention.
- **Monitoring & observability:** mail queue and bounce monitoring, DMARC report ingestion, uptime/health metrics and alerting.
- **Administration & automation:** web admin UI plus API/SCIM for provisioning, scripted onboarding/offboarding and RBAC.
- **Infrastructure & scaling:** HA design for mail and Nextcloud components, storage sizing, snapshots and failover/autoscale plans.
- **Cost, support & SLA:** predictable pricing or ops cost estimate, support channels, on-call runbook and escalation path.
- **Pilot & testing capability:** staging environment, deliverability testing tools, small-user pilot and rollback checklist.
- **User docs & training:** clear migration guides for Outlook/Apple Mail/Android, 2FA enrollment, and troubleshooting knowledge-base.

## Google ecosystem — required coverage

| Google service                      | Priority                                      | Replacement target                                |
| ----------------------------------- | --------------------------------------------- | ------------------------------------------------- |
| Gmail                               | **Required**                                  | Managed email (kSuite / Mailbox.org / Proton)     |
| Google Drive                        | **Required**                                  | kDrive (Sol. 1) or Nextcloud (Sol. 2/3)           |
| Google Docs / Sheets / Slides       | **Required** (no simultaneous editing needed) | OnlyOffice via kDrive or self-hosted              |
| Google Photos                       | **Required**                                  | Immich on VPS                                     |
| Google Calendar                     | **Required**                                  | CalDAV (kSuite / Mailbox.org / Nextcloud)         |
| Google Contacts                     | **Required**                                  | CardDAV (kSuite / Mailbox.org / Nextcloud)        |
| Google Tasks                        | **Required**                                  | CalDAV tasks (integrated with calendar)           |
| Shared drives / Team drives         | **Required**                                  | kDrive shared folders or Nextcloud Group folders  |
| Web-based file access (iPhone/iPad) | **Required**                                  | kDrive app or Nextcloud mobile app                |
| Security & endpoint management      | **Required**                                  | Provider spam/AV + MTA‑STS/DMARC; Bitwarden 2FA   |
| Backups & retention                 | **Required**                                  | Provider versioning + BorgBackup/restic on VPS    |
| Admin console / Provisioning        | **Required**                                  | kSuite Manager or Hetzner + Nextcloud admin       |
| Workspace APIs / automation         | **Required**                                  | Terraform / scripting + Bitwarden CLI for secrets |
| Drive File Stream / Desktop sync    | Optional (web access required)                | kDrive desktop or Nextcloud desktop client        |
| Google Meet                         | Optional (not currently used)                 | Nextcloud Talk or Jitsi                           |
| Google Chat / Spaces                | Optional (not currently used)                 | Nextcloud Talk or Matrix                          |
| Google Forms                        | Optional                                      | Nextcloud Forms                                   |
| Google Groups                       | Optional                                      | Mailbox.org groups or Mailman3                    |
| Google Keep                         | Optional (not currently used)                 | Nextcloud Notes or Standard Notes                 |
| Google Sites                        | Optional (not currently used)                 | Static site or lightweight CMS                    |
| Google Vault                        | Optional                                      | Provider archiving or Dovecot archive             |

## Long list — candidate systems

Evaluation criteria: **Privacy** (EU hosting, DPA, encryption) · **Cost** (per-user or flat) · **Simplicity** (fewer moving parts, integration) · **Coverage** (how many Google apps it replaces in one system).

### A. All-in-one managed platforms (single vendor covers most needs)

| #   | Provider                     | HQ   | Covers                                                                           | Notes                                                                                                                                                       |
| --- | ---------------------------- | ---- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Infomaniak kSuite**        | CH 🇨🇭 | Mail, Drive (kDrive), Docs (OnlyOffice), Calendar, Contacts, Meet, Tasks         | Swiss privacy (nFADP/GDPR), custom domains, 2 TB storage, OnlyOffice collab, webmail + mobile apps. Very close Google Workspace replacement. ~€5-7/user/mo. |
| 2   | **Mailbox.org Business**     | DE 🇩🇪 | Mail, Drive (OX Drive), Docs (OX Docs), Calendar, Contacts, Tasks, Video (Jitsi) | German privacy, Open-Xchange based, PGP built-in, CalDAV/CardDAV, custom domains, 50 GB mail+cloud. ~€3-9/user/mo.                                          |
| 3   | **Mailfence**                | BE 🇧🇪 | Mail, Docs, Calendar, Contacts, Groups, Drive                                    | Belgian privacy, E2E encryption (PGP/S/MIME), custom domains, CalDAV/CardDAV. Smaller storage. ~€3-8/user/mo.                                               |
| 4   | **Kolab Now**                | CH 🇨🇭 | Mail, Calendar, Contacts, Files, Notes, Tasks, Video (Jitsi)                     | Swiss hosted Kolab Groupware, CalDAV/CardDAV, IMAP, custom domains. ~€5-9/user/mo.                                                                          |
| 5   | **Proton for Business**      | CH 🇨🇭 | Mail, Calendar, Drive, VPN                                                       | E2E encrypted, Swiss privacy, custom domains, bridge for IMAP clients. Limited collab editing; no integrated docs/sheets yet. ~€8-13/user/mo.               |
| 6   | **Tutanota (Tuta) Business** | DE 🇩🇪 | Mail, Calendar, Contacts                                                         | E2E encrypted, German hosting. No Drive/Docs/Photos equivalent—needs pairing. ~€6-8/user/mo.                                                                |
| 7   | **Disroot**                  | NL 🇳🇱 | Mail, Cloud (Nextcloud), Chat (XMPP), Forum, Pads, Upload                        | Community/donation-based, Nextcloud backend, NL hosted. Good for simple setups. Free / donation.                                                            |

### B. Managed Nextcloud + Mail combos (two vendors, high integration)

| #   | Combo                                           | Covers                                                | Notes                                                                                                                                   |
| --- | ----------------------------------------------- | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 8   | **Hetzner Managed Nextcloud** + **Mailbox.org** | Files, Docs, Photos, Calendar, Contacts, Tasks + Mail | Hetzner Storage Share (managed Nextcloud) €3-5/user + Mailbox.org for mail. Both DE. Simple, cheap, integrated via CalDAV.              |
| 9   | **Infomaniak kDrive** + **Infomaniak Mail**     | Files, Docs, Photos + Mail                            | All from one Swiss vendor; effectively kSuite components used separately if desired.                                                    |
| 10  | **IONOS HiDrive** + **IONOS Mail**              | Files + Mail                                          | German, cheap (€1-5/user), but limited collab editing and no photos app.                                                                |
| 11  | **Murena (e.Foundation)**                       | Mail, Cloud, Docs, Office                             | EU-hosted, privacy-focused (deGoogled), Nextcloud-based cloud + email. Aimed at consumers but has family/small-team plans. ~€5/user/mo. |

### C. Self-hosted app platforms (on EU VPS — for files, photos, home-grown apps)

> **Note:** self-hosted MTA options (Mailcow, Mail-in-a-Box, Mailu, iRedMail, Modoboa) are **excluded** — email must be managed (see Context & Constraints). Listed here only as app hosting platforms.

| #   | Platform                               | Covers                                                                                       | Notes                                                                                                                      |
| --- | -------------------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| 12  | **Nextcloud Hub** (self-hosted)        | Files, Docs (OnlyOffice/Collabora), Photos, Calendar, Contacts, Tasks, Talk, Mail (client)   | Covers everything except MTA; use alongside a managed mail provider.                                                       |
| 13  | **Immich** (self-hosted)               | Photos (Google Photos clone: timeline, AI, face recognition, mobile upload)                  | Best Google Photos replacement; active development; runs alongside Nextcloud.                                              |
| 14  | **OnlyOffice Docs** (Docker)           | Document collaboration server                                                                | Integrates with Nextcloud; best MS/Google format compatibility.                                                            |
| 15  | **Cloudron**                           | App hosting platform (Nextcloud, OnlyOffice, PhotoPrism, home-grown apps, LDAP/SSO, backups) | One-click installs, automatic updates, LDAP/SSO baked in. Paid license (~€15/mo). Good platform for home-grown apps.       |
| 16  | **Cosmos Cloud**                       | Docker app hosting with SSO, reverse proxy, automated certs                                  | Lighter free/open-source alternative to Cloudron.                                                                          |
| 17  | **k3s / k8s** (lightweight Kubernetes) | Container orchestration for home-grown apps + self-hosted services                           | k3s is easy single-node or small-cluster Kubernetes; good for home-grown apps; add Helm charts for Nextcloud, Immich, etc. |
| 18  | **YunoHost**                           | Meta-installer (Nextcloud, OnlyOffice, PhotoPrism, apps), LDAP, SSO, Let's Encrypt           | Simplest full self-hosting path; less suited for home-grown custom app workloads.                                          |

### D. EU VPS providers (to replace Kamatera if self-hosting)

| #   | Provider                    | HQ   | Notes                                                                        |
| --- | --------------------------- | ---- | ---------------------------------------------------------------------------- |
| 22  | **Hetzner Cloud**           | DE 🇩🇪 | Best price/performance in EU. €4-20/mo for capable VPS. Excellent network.   |
| 23  | **Scaleway**                | FR 🇫🇷 | French cloud, good APIs, object storage, managed Kubernetes if needed.       |
| 24  | **OVHcloud**                | FR 🇫🇷 | Large EU provider, VPS from €3.50/mo, dedicated servers, good IP reputation. |
| 25  | **Contabo**                 | DE 🇩🇪 | Very cheap (€5-7/mo for 4 vCPU), EU DCs, but support is basic.               |
| 26  | **Netcup**                  | DE 🇩🇪 | German quality VPS, €3-8/mo, good community reputation.                      |
| 27  | **Infomaniak Public Cloud** | CH 🇨🇭 | Swiss, OpenStack-based, integrates with their managed services.              |
| 28  | **Exoscale**                | CH 🇨🇭 | Swiss, simple API, object storage, managed DBaaS.                            |

### E. Photo management (dedicated — if platform doesn't cover it well)

| #   | System                          | Notes                                                                                                       |
| --- | ------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 29  | **PhotoPrism**                  | AI tagging, face recognition, deduplication, mobile upload. Self-hosted.                                    |
| 30  | **Immich**                      | Google Photos clone (timeline, mobile auto-upload, face recognition). Self-hosted, very active development. |
| 31  | **Nextcloud Photos + Memories** | Built into Nextcloud, AI tagging via Recognize app. Simpler but less polished than Immich.                  |
| 32  | **Ente**                        | E2E encrypted photo storage, EU servers, mobile apps. Managed. ~€10/100GB/yr.                               |

### F2. Proton family & related services

- **Proton Mail** — secure, zero‑access email with custom domains; paid Family/Business plans support multiple users and domain hosting; good deliverability and low ops overhead.
- **Proton Drive** — client‑side encrypted file storage and sharing; strong privacy but limited real‑time collaborative editing compared with OnlyOffice/Collabora.
- **Proton Calendar** — encrypted calendar with ICS import/export and mobile sync.
- **Proton Contacts** — encrypted contacts storage with vCard import/export.
- **Proton Pass** — password manager integrated with Proton accounts (optional add‑on). Note: an existing Bitwarden Team account is already in use and can be retained instead of Proton Pass.
- **Proton VPN** — optional VPN service for network privacy and location masking.
- **Proton Bridge** — desktop IMAP/SMTP bridge for using Proton Mail with standard email clients (paid plan feature).

Notes: Proton is Swiss‑hosted with a strong privacy posture and zero‑access encryption for Drive/mail. It can serve as a single‑vendor, low‑ops replacement for many Workspace needs; pair with Nextcloud/OnlyOffice or Immich where Proton lacks collaboration or advanced photo features.

### F. Summary — fewest systems to cover all needs (5 users, ~5 TB, + app hosting)

| Approach                                          | Systems needed                    | Ops effort  | Cost estimate (5 users)  |
| ------------------------------------------------- | --------------------------------- | ----------- | ------------------------ |
| **Infomaniak kSuite + Immich on Hetzner VPS**     | kSuite + 1 VPS (Immich free)      | Low–Medium  | ~€65-83/mo ✅ recommended |
| **Mailbox.org + Hetzner Nextcloud/Immich/Apps**   | Mailbox.org + 1 VPS + Storage Box | Medium      | ~€50-60/mo               |
| **Proton Family + Hetzner Nextcloud/Immich/Apps** | Proton + 1 VPS + Storage Box      | Medium      | ~€65-75/mo               |
| **Infomaniak kSuite + Hetzner VPS (k3s)**         | kSuite + 1 VPS (k3s)              | Medium–High | ~€65-85/mo               |

---

## Three proposed solutions (5 users, ~1 TB/user)

### Solution 1 — Recommended for simplicity: Infomaniak kSuite + Immich on Hetzner VPS

Best choice for a non-tech-savvy family. kSuite is a single Swiss platform covering everything the family touches (mail, drive, docs, calendar, contacts) — one login, one app, one admin panel. The VPS is needed anyway for home-grown apps, so Immich runs there for free (no Ente subscription needed).

**Why kSuite is the simplest for family members:**
- Single login for mail + drive + calendar + contacts
- Native mobile apps (iOS/Android) that work like Google's
- No VPN, bridge, or CalDAV configuration needed — everything just works
- One admin panel to manage 5 users, domains and aliases
- Non-tech users never touch the VPS

**Why Immich instead of Ente:**
- VPS is already required for home-grown apps — Immich runs on that same server at no extra cost
- Immich has better UX than Ente (Google Photos timeline, face recognition, shared albums, mobile auto-upload)
- Ente only makes sense if you want zero self-hosting; that's no longer true here

| Capability             | Provider                                                                           | Notes                                                                                                                       |
| ---------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Email (managed)        | Infomaniak kSuite Mail                                                             | Custom domains, aliases, forwarding, webmail, CalDAV/CardDAV, ActiveSync. SPF/DKIM/DMARC managed.                           |
| Calendar & Contacts    | Infomaniak kSuite                                                                  | Shared calendars, CalDAV/CardDAV, mobile sync.                                                                              |
| File sync & sharing    | Infomaniak kDrive                                                                  | 3 TB shared plan, web + desktop + mobile apps, OnlyOffice editing built-in.                                                 |
| Document collaboration | OnlyOffice (via kDrive)                                                            | Docs/Sheets/Slides editing in browser — no simultaneous editing required.                                                   |
| Photo management       | **Immich** (on Hetzner VPS)                                                        | Google Photos clone: timeline, face recognition, mobile auto-upload, shared albums. Free on existing VPS.                   |
| Tasks                  | Infomaniak kSuite (CalDAV tasks)                                                   | Integrated with calendar apps.                                                                                              |
| Password manager       | Bitwarden Team (existing)                                                          | Keep existing Team account; no change.                                                                                      |
| App hosting / Compute  | **Hetzner VPS** (CPX31 or similar)                                                 | Home-grown apps + Immich on Docker/k3s; EU/DE hosted.                                                                       |
| Secret management      | **Bitwarden CLI → Vaultwarden** (start) · **Infisical** (self-hosted, when needed) | `bw get` for simple CI/script secrets; add Infisical on the same VPS for per-app/per-env namespacing when complexity grows. |
| Backups                | Infomaniak kDrive versioning + BorgBackup on VPS                                   | 30-day file versioning for kDrive; encrypted VPS backup for Immich.                                                         |
| Admin / DNS            | Infomaniak Manager + DNS registrar                                                 | Web UI, custom domains, alias domains, forwarding for all 5 domains.                                                        |

**Estimated monthly cost (5 users, ~5 TB total):**

| Item                                               | Cost                                                         |
| -------------------------------------------------- | ------------------------------------------------------------ |
| Infomaniak kSuite (5 users, kDrive 3 TB)           | ~€25-35/mo                                                   |
| Infomaniak extra kDrive storage to reach ~5 TB     | ~€5-10/mo                                                    |
| Hetzner VPS for apps + Immich (CPX31)              | ~€15/mo                                                      |
| Domains (keep existing 5)                          | ~€5-8/mo                                                     |
| Vaultwarden (self-hosted, replaces Bitwarden Team) | €0 (free on existing VPS, saves ~€15/mo)                     |
| **Total**                                          | **~€50-68/mo**                                               |
| **vs current spend**                               | ~€58-81/mo — same or cheaper, 2 extra users + better privacy |

**Pros:** simplest for non-tech family members; one Swiss vendor for everything family-facing; no VPN/bridge/CalDAV setup; best deliverability; Immich + Vaultwarden on VPS are free; saves ~€15/mo vs current Bitwarden Team.
**Note on Vaultwarden:** family uses the same Bitwarden app on Firefox and iPhone — zero UX change. Ensure daily encrypted backup of `/vaultwarden/data/` on the VPS.
**Cons:** Infomaniak vendor lock-in risk (less severe than Google); VPS still needed for apps/Immich but family never touches it.

---

### Solution 2 — Hybrid (Mailbox.org + self-hosted Nextcloud + Immich on Hetzner)

Managed email for deliverability + self-hosted storage/photos for maximum space and control.

| Capability             | Provider                                                                           | Notes                                                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Email (managed)        | **Mailbox.org** (5× Business plan)                                                 | German hosting, custom domains, alias domains, PGP, CalDAV/CardDAV, OX Drive (limited). SPF/DKIM/DMARC managed by provider.              |
| Calendar & Contacts    | Mailbox.org (CalDAV/CardDAV)                                                       | Shared calendars, delegation, ICS import, vCard sync.                                                                                    |
| File sync & sharing    | **Nextcloud** (self-hosted on Hetzner)                                             | 5 TB+ Hetzner Storage Box or local disk. Desktop/mobile/web sync.                                                                        |
| Document collaboration | **OnlyOffice** (Docker on same VPS)                                                | Integrated with Nextcloud for in-browser editing.                                                                                        |
| Photo management       | **Immich** (self-hosted on Hetzner)                                                | Google Photos clone: timeline, face recognition, mobile auto-upload, sharing.                                                            |
| Tasks                  | Nextcloud Tasks (CalDAV) or Mailbox.org tasks                                      | Synced via CalDAV to any client.                                                                                                         |
| Password manager       | **Vaultwarden** (on Hetzner VPS)                                                   | Self-hosted Bitwarden-compatible server; same Firefox/iPhone app UX; free on existing VPS. Cancel Bitwarden Team. Backup vault DB daily. |
| App hosting / Compute  | **Hetzner VPS** (same VPS or dedicated node)                                       | Home-grown apps + Nextcloud + Immich + OnlyOffice on Docker/k3s. IaC with Terraform/Ansible.                                             |
| Secret management      | **Bitwarden CLI → Vaultwarden** (start) · **Infisical** (self-hosted, when needed) | `bw get` for simple CI/script secrets; add Infisical on the same VPS for per-app/per-env namespacing when complexity grows.              |
| Backups                | Hetzner Storage Box + BorgBackup/restic                                            | Encrypted off-server backups, automated daily.                                                                                           |
| Admin / DNS            | Hetzner Cloud Console + DNS registrar                                              | Terraform/Ansible for IaC; Bitwarden CLI (works with Vaultwarden) for CI secret retrieval.                                               |

**Estimated monthly cost (5 users, ~5 TB):**

| Item                                              | Cost                                            |
| ------------------------------------------------- | ----------------------------------------------- |
| Mailbox.org Business (5× €3/mo)                   | €15/mo                                          |
| Hetzner VPS (CPX31: 4 vCPU, 8 GB RAM, 160 GB SSD) | €15/mo                                          |
| Hetzner Storage Box (5 TB, BX40)                  | €16/mo                                          |
| Domains (keep existing 5)                         | ~€5-8/mo                                        |
| Bitwarden (keep existing)                         | ~€15/mo                                         |
| **Total**                                         | **~€66-69/mo**                                  |
| **vs current spend**                              | ~€58-81/mo (more users, EU privacy, no MTA ops) |

**Pros:** managed email (zero MTA ops), German privacy, cheap storage, full control over files/photos/apps, standard protocols (IMAP/CalDAV/CardDAV), IaC-friendly.
**Cons:** you maintain Nextcloud + Immich + OnlyOffice + home-grown apps; less polished UX for non-tech family members than kSuite.

---

### Solution 3 — Hybrid minimal (Proton Family + self-hosted Nextcloud + Immich on Hetzner)

Proton handles email/calendar/contacts/VPN with zero-access encryption. Self-hosted covers storage and photos.

| Capability             | Provider                                                                           | Notes                                                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Email (managed)        | **Proton Mail** (Family plan, 6 users)                                             | Swiss E2E encrypted, custom domains, alias domains, Proton Bridge for IMAP clients. SPF/DKIM/DMARC managed.                              |
| Calendar & Contacts    | Proton Calendar + Proton Contacts                                                  | Encrypted, mobile sync. Note: no CalDAV — uses Proton apps only.                                                                         |
| VPN                    | Proton VPN (included in Family)                                                    | Network privacy for all family members.                                                                                                  |
| Password manager       | **Vaultwarden** (on Hetzner VPS)                                                   | Self-hosted Bitwarden-compatible server; same Firefox/iPhone app UX; free on existing VPS. Cancel Bitwarden Team. Backup vault DB daily. |
| File sync & sharing    | **Nextcloud** (self-hosted on Hetzner)                                             | 5 TB+, web/desktop/mobile access.                                                                                                        |
| Document collaboration | **OnlyOffice** (Docker on same VPS)                                                | Integrated with Nextcloud.                                                                                                               |
| Photo management       | **Immich** (self-hosted on Hetzner)                                                | Timeline, face recognition, mobile auto-upload.                                                                                          |
| Tasks                  | Nextcloud Tasks (CalDAV)                                                           | Or any CalDAV client syncing to Nextcloud.                                                                                               |
| App hosting / Compute  | **Hetzner VPS** (same VPS or dedicated node)                                       | Home-grown apps + Nextcloud + Immich + OnlyOffice on Docker/k3s.                                                                         |
| Secret management      | **Bitwarden CLI → Vaultwarden** (start) · **Infisical** (self-hosted, when needed) | `bw get` for simple CI/script secrets; add Infisical on the same VPS for per-app/per-env namespacing when complexity grows.              |
| Backups                | Hetzner Storage Box + BorgBackup/restic                                            | Encrypted off-server backups.                                                                                                            |
| Admin / DNS            | Hetzner Cloud + Proton Admin + DNS registrar                                       | Proton admin for mail; Hetzner for infra; Bitwarden CLI (works with Vaultwarden) for CI secrets.                                         |

**Estimated monthly cost (5 users, ~5 TB):**

| Item                                                  | Cost                                                 |
| ----------------------------------------------------- | ---------------------------------------------------- |
| Proton Family plan (up to 6 users, 3 TB Proton Drive) | ~€30/mo                                              |
| Hetzner VPS (CPX31: 4 vCPU, 8 GB RAM, 160 GB SSD)     | €15/mo                                               |
| Hetzner Storage Box (5 TB, BX40)                      | €16/mo                                               |
| Domains (keep existing 5)                             | ~€5-8/mo                                             |
| Vaultwarden (self-hosted, replaces Bitwarden Team)    | €0 (free on existing VPS, saves ~€15/mo)             |
| **Total**                                             | **~€66-69/mo**                                       |
| **vs current spend**                                  | ~€58-81/mo — slight premium for E2E encryption + VPN |

**Pros:** strongest encryption (zero-access mail + E2E), VPN included, Swiss privacy, Proton ecosystem very polished on mobile. Vaultwarden on VPS saves ~€15/mo vs Bitwarden Team.
**Cons:** no standard CalDAV/CardDAV (locked to Proton apps for calendar/contacts sync), most expensive of the three options, Proton Drive overlaps with Nextcloud (paying for both), less flexible for third-party email clients.

---

### Comparison matrix

| Criterion                                        |       Solution 1 (Infomaniak)       |  Solution 2 (Mailbox.org + Hetzner)   |     Solution 3 (Proton + Hetzner)     |
| ------------------------------------------------ | :---------------------------------: | :-----------------------------------: | :-----------------------------------: |
| **Privacy**                                      |  ★★★★☆ (Swiss, encrypted at rest)   |  ★★★★☆ (German, TLS + PGP optional)   |    ★★★★★ (Swiss, zero-access E2E)     |
| **Cost /mo (Vaultwarden on VPS, domains incl.)** |               ~€50-68               |                ~€51-54                |                ~€66-69                |
| **Simplicity**                                   |        ★★★★★ (fully managed)        | ★★★☆☆ (managed mail + self-host apps) | ★★★☆☆ (managed mail + self-host apps) |
| **Storage (1 TB/user)**                          |          ~5 TB achievable           |       5 TB+ easy (Storage Box)        |       5 TB+ easy (Storage Box)        |
| **Email flexibility**                            |      ★★★★★ (IMAP, any client)       |       ★★★★★ (IMAP, any client)        |    ★★★☆☆ (Bridge needed for IMAP)     |
| **CalDAV/CardDAV**                               |           ★★★★★ (native)            |            ★★★★★ (native)             |       ★★☆☆☆ (Proton apps only)        |
| **Photo management**                             |     ★★★★★ (Immich on VPS, free)     |     ★★★★★ (Immich, full-featured)     |     ★★★★★ (Immich, full-featured)     |
| **Doc collaboration**                            |    ★★★★☆ (OnlyOffice via kDrive)    |    ★★★★★ (OnlyOffice self-hosted)     |    ★★★★★ (OnlyOffice self-hosted)     |
| **App hosting**                                  | ★★★☆☆ (separate Hetzner VPS needed) |    ★★★★★ (VPS already hosts apps)     |    ★★★★★ (VPS already hosts apps)     |
| **Admin overhead**                               |        Low (managed + 1 VPS)        |    Medium (VPS with several apps)     |    Medium (VPS with several apps)     |
| **Vendor lock-in risk**                          |         Medium (Infomaniak)         |       Low (standard protocols)        |   Medium (Proton encryption format)   |

---

**Next step:** pick one solution (or blend elements) → build detailed migration plan.

