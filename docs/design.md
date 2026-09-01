# Haven Design and Architecture

## Design Goal

You want your family's photos, passwords, and files under your own control — not scattered across Google, Apple, and random SaaS subscriptions. Haven gives you a self-hosted platform that is invisible to your family (they just use apps they already know) while keeping you in full control of the data, costs, and privacy. It is designed to be deployed once and forgotten, not maintained daily.

You want to provide the simplest day-to-day experience to your family members. A single Swiss vendor (Infomaniak) covers everything the family touches — email, files, docs, calendar, contacts. The VPS is invisible to the family; it runs Immich (photos), Jellyfin (media), Nextcloud (documents), Kavita (EPUB/PDF library), Vaultwarden (passwords), Authentik (SSO), and your containerized apps.

Application secrets are managed by **Infisical Cloud** (free tier). Deployment credentials (API keys, SSH keys) are stored in **Bitwarden Cloud** (free tier). Terraform state lives in **Terraform Cloud** (free tier). This cloud-first approach **eliminates the bootstrap problem** — you can deploy from a clean machine with no prior self-hosted infrastructure.

---

## Architecture Reference

For system topology, component inventory, node specifications, and data durability model, see **[architecture.md](architecture.md)**.

---

## Domain & Email Layout

**Domain strategy:** Multiple domain registrations for mail and static content, all managed at INWX. Each family can choose their own naming scheme. You will need at least one base domain for mailboxes.

```text
Mail — Base domain        → kSuite MX → primary mailboxes (5 users)
                             └─ Primary family email identity

Mail — Sandbox            → kSuite MX → aliases to base domain
                             └─ Testing/dev addresses

Mail — Alias domains      → kSuite MX → forwards to base mailboxes
                             └─ Legacy names, brand variants (add as many as needed)

Static sites              → Caddy on Hearth → static content (no email)
                             └─ Portfolio, blogs, or other static assets (via IP or subdomain)
```

**Adding more domains:** To add a mail alias, register at INWX and configure forwarding in kSuite (no new mailbox). Static sites point DNS to Hearth's IP and add a Caddyfile entry.

### INWX domain pricing

| Domain category         | TLD               | Annual                  | Notes                                   |
| ----------------------- | ----------------- | ----------------------- | --------------------------------------- |
| Base domain             | `.xyz` (or other) | ~€24/yr                 | Primary mail identity                   |
| Sandbox domain          | `.dev`            | ~€18/yr                 | HTTPS mandatory (auto-handled by Caddy) |
| Mail alias domain(s)    | varies            | ~€10-50/yr each         | Add as needed; no mailbox required      |
| Static website(s)       | varies            | ~€5-30/yr each          | Points to Hearth IP; DNS records vary   |
| **Example (4 domains)** |                   | **~€70/yr (~€5.80/mo)** | Costs scale with domain count and TLDs  |

### Mailboxes

Five kSuite mailboxes on the base mail domain, one per family member.

| Mailbox                 | Member | Notes                                 |
| ----------------------- | ------ | ------------------------------------- |
| `parent1@{base-domain}` | Parent |                                       |
| `parent2@{base-domain}` | Parent |                                       |
| `child1@{base-domain}`  | Child  | server-side copy forwarded to parents |
| `child2@{base-domain}`  | Child  | server-side copy forwarded to parents |
| `child3@{base-domain}`  | Child  | server-side copy forwarded to parents |

### Distribution groups

Configured in kSuite Mail Service → Distribution lists (no extra mailbox licence needed).

| Group address          | Members         | Purpose                   |
| ---------------------- | --------------- | ------------------------- |
| `family@{base-domain}` | all 5 mailboxes | Family-wide announcements |

### Parental oversight — child mail forwarding

Each child's mailbox has a server-side **keep copy + forward** rule. Configured in: **kSuite Manager → Mail Service → [child mailbox] → Redirections / Forwarding**

| Child mailbox          | Forward copy to                                  |
| ---------------------- | ------------------------------------------------ |
| `child1@{base-domain}` | `parent1@{base-domain}`, `parent2@{base-domain}` |
| `child2@{base-domain}` | `parent1@{base-domain}`, `parent2@{base-domain}` |
| `child3@{base-domain}` | `parent1@{base-domain}`, `parent2@{base-domain}` |

---

## Design Rationale

**Two-layer separation:**

- Hearth (identity/secrets) runs Docker Compose on stable hardware.
- Forge (workloads) runs k3s and can be destroyed/rebuilt freely.
- Makes Hearth deployment simple and boring — no experiments, no dependency churn
- Allows Forge to be replaced without affecting family authentication or passwords
- Eliminates risk of one failed app taking down the entire platform

**Single Swiss vendor (Infomaniak)** for base services eliminates:

- Email hosting ops (managing SMTP/IMAP/spam/deliverability)
- File sync redundancy concerns (handled by Infomaniak)
- GDPR/privacy concerns (Swiss nFADP compliance, GDPR, DPA)
- Multi-vendor coordination costs

**Self-hosted VPS tier** for apps that need to:

- Store data on your own infrastructure (Storage Box — Immich, Jellyfin, Nextcloud, Kavita all mount it directly, since none of them have native S3 support)
- Integrate across multiple services (Authentik SSO)
- Run custom workloads (home-grown apps)
- Avoid third-party custody of sensitive data

**Cloud-first bootstrap** — deployment credentials and infrastructure state live in free-tier cloud services before any VPS exists:

- **Bitwarden Cloud** (free) → API keys, SSH keys, tokens needed to deploy
- **Infisical Cloud** (free) → runtime application secrets (env vars, DB passwords)
- **Terraform Cloud** (free) → remote state backend, no local state files
- **GitHub** → source repo + GitHub Actions CI/CD pipelines

This means a full redeploy from scratch requires only a Bitwarden Cloud login, a GitHub account, and a Hetzner account — no chicken-and-egg problem.

**Storage Box for all app data** (not S3, not local volumes) — split across **two separate Storage Box products** so backups and live media/documents can each scale to their own cheapest-fitting tier independently:

- **`haven-backup`** (1 TB) — Hearth + Forge BorgBackup repos only (`sub1`/`sub2`)
- **`haven-data`** (1 TB, separate product) — all live app data, split into two sub-accounts: `media` (Immich only) and `docs` (Nextcloud + Kavita + Jellyfin, since they share one tree — Jellyfin moved here 2026-08-29, see jellyfin.md)

This split exists because:

- None of these apps have native S3 API support — they all just want a filesystem path, so an S3/FUSE layer would add complexity (and, per this project's own experience, real reliability bugs) for zero benefit
- Storage Box's unlimited traffic and flat-rate pricing suit large binary libraries (photos, video, documents) far better than per-GB egress billing
- Storage Box billing is per-box/fixed-tier, not incremental — backups and live media have very different growth curves, so keeping them on the same box risks the whole box (including the small backup portion) being forced into a much bigger tier just because the live-data side grew
- Survives Forge cluster destruction — data isn't tied to node/cluster lifecycle
- Both boxes are covered by the daily offsite sync to Infomaniak kDrive
- Three S3-compatible buckets (`haven-photos`, `haven-media`, `haven-docs`) remain provisioned and reserved, in case a future app genuinely needs the S3 API (public URLs, bucket policies) — none currently do

---

## Security Posture

| Layer             | Controls                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| kSuite            | Swiss nFADP + GDPR, DPA, TLS in transit, encrypted at rest, DKIM/DMARC managed; daily independent backup of email (IMAP via mbsync) + calendar/contacts (CalDAV/CardDAV via vdirsyncer) to Hearth, folded into Hearth's own Borg archive + kDrive offsite sync (see [backup.md](guides/backup.md#ksuite-backup-email--calendarcontacts)); kDrive file-level backup (photos/documents) not yet implemented — deferred pending storage capacity/cost review                                                                                                    |
| VPS OS            | UFW (80/443/SSH only), SSH key-only, Fail2Ban, unattended-upgrades                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Caddy             | Auto HTTPS, HSTS, TLS 1.2/1.3 only, HTTP/2                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Authentik         | 2FA enforced (TOTP/WebAuthn), OIDC provider for all services, daily encrypted DB backup                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Vaultwarden       | HTTPS only, OIDC login via Authentik, admin token protected, daily backup                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Immich            | OIDC login via Authentik, not exposed without auth; library stored on the `haven-data` Storage Box's `media` sub-account via SMB mount (no native S3 support in Immich); replicated to Infomaniak kDrive                                                                                                                                                                                                                                                                                                                                                     |
| Jellyfin          | OIDC login via Authentik; library on the `haven-data` Storage Box's `media` sub-account (SMB mount, shared with Immich, read-only from VPS); no originals on cluster SSD; software transcode only (no GPU)                                                                                                                                                                                                                                                                                                                                                   |
| Nextcloud         | OIDC login via Authentik; document archive/browsing layer (not the live sync drive — that's Infomaniak kDrive); storage on the `haven-data` Storage Box's `docs` sub-account (SMB mount) via the External Storage app                                                                                                                                                                                                                                                                                                                                        |
| Kavita            | Local auth (no SSO); reads the same shared documents tree as Nextcloud, read-only, from the `haven-data` Storage Box's `docs` sub-account (SMB mount)                                                                                                                                                                                                                                                                                                                                                                                                        |
| Infisical Cloud   | Free-tier cloud service; secrets never in plain env files or git; services access via machine identities scoped per environment; UI at app.infisical.com; no self-hosted instance to maintain or bootstrap                                                                                                                                                                                                                                                                                                                                                   |
| Container updates | Core VPS: image tags pinned in `haven`; `docker compose pull && up -d`; monthly review. Workload VPS: Helm versions pinned in `haven`; `helm upgrade`; Dependabot on `haven` for digest updates                                                                                                                                                                                                                                                                                                                                                              |
| IaC secrets       | Deployment credentials (Hetzner API key, SSH keys, tokens) stored in Bitwarden Cloud (free tier) before any infrastructure exists — no bootstrap dependency on a running self-hosted service; runtime app secrets from Infisical Cloud machine identities; Terraform state in Terraform Cloud; no secrets in git                                                                                                                                                                                                                                             |
| Monitoring        | Healthchecks.io for BorgBackup dead-man's switch; UptimeRobot for external endpoint pings. A per-service health dashboard (e.g. Gatus) is not yet built                                                                                                                                                                                                                                                                                                                                                                                                      |
| Backups           | **Tier 1:** BorgBackup (Hearth + Forge) daily to `haven-backup` Storage Box — Hearth (Authentik/Vaultwarden DB+config + kSuite email/calendar/contacts mirror) and Forge (Postgres dumps, k3s datastore, app config PVCs). **Tier 2:** daily rclone sync of both Storage Boxes (`haven-backup` + `haven-data`) to Infomaniak kDrive 3 TB (~03:00 UTC). Borg encryption key in Vaultwarden; restore tested monthly. kDrive file-level backup (photos/documents) not yet implemented — see [backup.md](guides/backup.md#ksuite-backup-email--calendarcontacts) |

---

## Risk & Mitigation

| Risk                                            | Impact                                                                                                                                                                                          | Mitigation                                                                                                                                                                                                                                                                                                                                                        |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Infomaniak outage**                           | kSuite (email, calendar, files) unavailable; kDrive sync delayed                                                                                                                                | Daily independent backup of email/calendar/contacts to Hearth (Tier 1) + kDrive (Tier 2); 30-day version history on kDrive; kSuite's DPA guarantees; SLA enforcement via support ticket. kDrive file-level backup (photos/documents) still relies solely on Infomaniak's own redundancy — see [backup.md](guides/backup.md#ksuite-backup-email--calendarcontacts) |
| **Hearth node failure**                         | Auth and secrets unavailable; Forge cannot deploy                                                                                                                                               | Daily encrypted BorgBackup to Storage Box; documented recovery procedure; tested monthly; deployment credentials in Bitwarden Cloud — can redeploy Hearth from scratch with only a Bitwarden Cloud login                                                                                                                                                          |
| **Forge cluster failure**                       | Immich, Jellyfin, Nextcloud, Kavita, apps down; family photos/media/documents unreachable                                                                                                       | All app data lives on the `haven-data` Storage Box (not tied to cluster lifecycle); cluster can be recreated in ~30 min via IaC and simply re-mounts the same Storage Box paths                                                                                                                                                                                   |
| **Storage Box data loss/corruption**            | Photos, media, and documents (or backups, if it's `haven-backup`) permanently lost                                                                                                              | Daily rclone sync to Infomaniak kDrive covers both Storage Boxes; manual restore tested quarterly                                                                                                                                                                                                                                                                 |
| **Hetzner account compromise**                  | Attacker gains access to VPS, S3, snapshots                                                                                                                                                     | SSH key-only auth + fail2ban; Private network for Forge; Hetzner API key stored only in Bitwarden Cloud (not in git); runtime secrets via Infisical Cloud machine identities (no secrets in git)                                                                                                                                                                  |
| **BorgBackup encryption key lost**              | Cannot restore Hearth or Forge backups                                                                                                                                                          | Borg repokey (strong passphrase) stored in Vaultwarden vault; backup tested monthly (restore from backup to temp VM)                                                                                                                                                                                                                                              |
| **Storage Box capacity exceeded**               | The affected box's writes fail (BorgBackup stops if `haven-backup`; Immich/Jellyfin/Nextcloud/Kavita writes fail if `haven-data`) — the other box is unaffected since they're separate products | Monitor capacity per box; upgrade the affected box to the next fixed tier (5/10/20 TB) before it's exceeded; alerting via Healthchecks.io dead-man's switch                                                                                                                                                                                                       |
| **Caddy cert renewal failure**                  | HTTPS breaks for all services                                                                                                                                                                   | cert-manager on Forge + Caddy on Hearth provide dual renewal paths; 30-day renewal window; manual fallback (change DNS, use self-signed)                                                                                                                                                                                                                          |
| **rclone sync to kDrive fails**                 | No offsite backup for 24h+                                                                                                                                                                      | Daily cron + dead-man's switch; manual retry procedure; periodic audit of kDrive sync completeness                                                                                                                                                                                                                                                                |
| **Child mailbox forwarding misconfigured**      | Parent oversight bypassed                                                                                                                                                                       | Quarterly audit of forwarding rules; documented in kSuite setup playbook; manual verification after changes                                                                                                                                                                                                                                                       |
| **Bitwarden Cloud deployment credentials lost** | Cannot bootstrap deployment; must regenerate all API keys and SSH keys manually                                                                                                                 | Export Bitwarden Cloud vault to encrypted `.json` quarterly and store offline; document all credential types and regeneration steps in runbook; Bitwarden Cloud free tier has no expiry                                                                                                                                                                           |

---

## Monthly Cost

> Updated 2026-09-01 with actual renewal/invoice figures, replacing the earlier per-resource estimates below (which were significantly off in both directions — Infomaniak was overestimated, Hetzner was underestimated).

| Item                                                             | Cost           |
| ---------------------------------------------------------------- | -------------- |
| Infomaniak (kSuite + kDrive, actual combined invoice)            | **€11/mo**     |
| Hetzner (Core VPS + Workload VPS + both Storage Boxes + S3)      | **€58/mo**     |
| Domains (4 × INWX, actual renewal pricing — see breakdown below) | **~€11.67/mo** |
| Bitwarden Cloud (deployment creds, free tier)                    | €0/mo          |
| Infisical Cloud (app secrets, free tier)                         | €0/mo          |
| Terraform Cloud (state backend, free tier)                       | €0/mo          |
| **Total**                                                        | **~€80.67/mo** |

**Domain renewal breakdown** (annual, ÷12 for the monthly line above):

| Domain           | TLD       | Annual renewal |
| ---------------- | --------- | -------------- |
| `huybrechts.xyz` | `.xyz`    | €31/yr         |
| `alderwyn.xyz`   | `.xyz`    | €31/yr         |
| `meeus.family`   | `.family` | €58/yr         |
| `huybrechts.dev` | `.dev`    | €20/yr         |
| **Total**        |           | **€140/yr**    |

> `.family` is the disproportionately expensive TLD here (€58/yr vs €20-31/yr for the others) — worth periodically re-confirming whether `meeus.family` addresses are still actively used before its next renewal.

