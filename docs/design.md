# Haven Design and Architecture

## Design Goal

You want your family's photos, passwords, and files under your own control — not scattered across Google, Apple, and random SaaS subscriptions. Haven gives you a self-hosted platform that is invisible to your family (they just use apps they already know) while keeping you in full control of the data, costs, and privacy. It is designed to be deployed once and forgotten, not maintained daily.

You want to provide the simplest day-to-day experience to your family members. A single Swiss vendor (Infomaniak) covers everything the family touches — email, files, docs, calendar, contacts. The VPS is invisible to the family; it runs Immich (photos), Vaultwarden (passwords), Authentik (SSO), and your containerized apps.

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

- Store data in your S3 buckets (Immich photos)
- Integrate across multiple services (Authentik SSO)
- Run custom workloads (home-grown apps)
- Avoid third-party custody of sensitive data

**Cloud-first bootstrap** — deployment credentials and infrastructure state live in free-tier cloud services before any VPS exists:

- **Bitwarden Cloud** (free) → API keys, SSH keys, tokens needed to deploy
- **Infisical Cloud** (free) → runtime application secrets (env vars, DB passwords)
- **Terraform Cloud** (free) → remote state backend, no local state files
- **GitHub** → source repo + GitHub Actions CI/CD pipelines

This means a full redeploy from scratch requires only a Bitwarden Cloud login, a GitHub account, and a Hetzner account — no chicken-and-egg problem.

**S3 object storage for originals** (not volumes) — Immich and archives live in S3 because:

- S3 is first-class in Immich (survives cluster destruction)
- No expensive egress if you rebuild Forge
- Scales independently of node capacity
- Daily replication to Infomaniak kDrive covers geographic redundancy

---

## Security Posture

| Layer             | Controls                                                                                                                                                                                                                                                                                                                                                                                                    |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| kSuite            | Swiss nFADP + GDPR, DPA, TLS in transit, encrypted at rest, DKIM/DMARC managed; ⚠ no independent backup of kSuite data — relies on Infomaniak redundancy + 30-day kDrive versioning; consider periodic IMAP/CardDAV/CalDAV export to VPS for cold copy                                                                                                                                                      |
| VPS OS            | UFW (80/443/SSH only), SSH key-only, Fail2Ban, unattended-upgrades                                                                                                                                                                                                                                                                                                                                          |
| Caddy             | Auto HTTPS, HSTS, TLS 1.2/1.3 only, HTTP/2                                                                                                                                                                                                                                                                                                                                                                  |
| Authentik         | 2FA enforced (TOTP/WebAuthn), OIDC provider for all services, daily encrypted DB backup                                                                                                                                                                                                                                                                                                                     |
| Vaultwarden       | HTTPS only, OIDC login via Authentik, admin token protected, daily backup                                                                                                                                                                                                                                                                                                                                   |
| Immich            | OIDC login via Authentik, not exposed without auth; originals stored in S3 `photos` bucket (Immich native S3 library support); replicated to Infomaniak kDrive                                                                                                                                                                                                                                              |
| Jellyfin          | OIDC login via Authentik; library on Storage Box NFS mount (read-only from VPS); no originals on cluster SSD; software transcode only (no GPU)                                                                                                                                                                                                                                                              |
| Infisical Cloud   | Free-tier cloud service; secrets never in plain env files or git; services access via machine identities scoped per environment; UI at app.infisical.com; no self-hosted instance to maintain or bootstrap                                                                                                                                                                                                  |
| Container updates | Core VPS: image tags pinned in `haven`; `docker compose pull && up -d`; monthly review. Workload VPS: Helm versions pinned in `haven`; `helm upgrade`; Dependabot on `haven` for digest updates                                                                                                                                                                                                             |
| IaC secrets       | Deployment credentials (Hetzner API key, SSH keys, tokens) stored in Bitwarden Cloud (free tier) before any infrastructure exists — no bootstrap dependency on a running self-hosted service; runtime app secrets from Infisical Cloud machine identities; Terraform state in Terraform Cloud; no secrets in git                                                                                            |
| Monitoring        | Gatus (VPS) for per-service health; Healthchecks.io for BorgBackup dead-man's switch; UptimeRobot for external endpoint pings                                                                                                                                                                                                                                                                               |
| Backups           | Two-tier strategy: **Tier 1** — BorgBackup (Hearth + Forge) daily to Storage Box BX11 (encrypted, repokey-blake2); Jellyfin media on Storage Box (NFS, always present). **Tier 2** — daily rclone sync of entire Storage Box + S3 buckets (`haven-photos`, `haven-media`, `haven-archive`, `haven-docs`) to Infomaniak kDrive 3 TB (~03:00 UTC). Borg encryption key in Vaultwarden; restore tested monthly |

---

## Risk & Mitigation

| Risk                                            | Impact                                                                          | Mitigation                                                                                                                                                                                               |
| ----------------------------------------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Infomaniak outage**                           | kSuite (email, calendar, files) unavailable                                     | Redundant backup to local kDrive; 30-day version history; DPA guarantees; SLA enforcement via support ticket                                                                                             |
| **Hearth node failure**                         | Auth and secrets unavailable; Forge cannot deploy                               | Daily encrypted BorgBackup to Storage Box; documented recovery procedure; tested monthly; deployment credentials in Bitwarden Cloud — can redeploy Hearth from scratch with only a Bitwarden Cloud login |
| **Forge cluster failure**                       | Immich, Jellyfin, apps down; family photos/media unreachable                    | Immich originals in S3 (survives rebuild); Jellyfin library on Storage Box NFS; all app state in S3 buckets; cluster can be recreated in ~30 min via IaC                                                 |
| **S3 bucket deletion**                          | Photos and media permanently lost                                               | Lifecycle policy prevents auto-deletion; daily rclone sync to Infomaniak kDrive; manual restore tested quarterly                                                                                         |
| **Hetzner account compromise**                  | Attacker gains access to VPS, S3, snapshots                                     | SSH key-only auth + fail2ban; Private network for Forge; Hetzner API key stored only in Bitwarden Cloud (not in git); runtime secrets via Infisical Cloud machine identities (no secrets in git)         |
| **BorgBackup encryption key lost**              | Cannot restore Hearth or Forge backups                                          | Borg repokey (strong passphrase) stored in Vaultwarden vault; backup tested monthly (restore from backup to temp VM)                                                                                     |
| **Storage Box capacity exceeded**               | BorgBackup fails; tier-1 backups stop                                           | Monitor capacity; tier-2 sync still runs to kDrive; alerting via Healthchecks.io dead-man's switch                                                                                                       |
| **Caddy cert renewal failure**                  | HTTPS breaks for all services                                                   | cert-manager on Forge + Caddy on Hearth provide dual renewal paths; 30-day renewal window; manual fallback (change DNS, use self-signed)                                                                 |
| **rclone sync to kDrive fails**                 | No offsite backup for 24h+                                                      | Daily cron + dead-man's switch; manual retry procedure; periodic audit of kDrive sync completeness                                                                                                       |
| **Child mailbox forwarding misconfigured**      | Parent oversight bypassed                                                       | Quarterly audit of forwarding rules; documented in kSuite setup playbook; manual verification after changes                                                                                              |
| **Bitwarden Cloud deployment credentials lost** | Cannot bootstrap deployment; must regenerate all API keys and SSH keys manually | Export Bitwarden Cloud vault to encrypted `.json` quarterly and store offline; document all credential types and regeneration steps in runbook; Bitwarden Cloud free tier has no expiry                  |

---

## Monthly Cost

| Item                                                 | Cost              |
| ---------------------------------------------------- | ----------------- |
| Infomaniak kSuite (5 users, kDrive 3 TB)             | ~€25-35/mo        |
| Infomaniak kDrive extra storage (to ~5 TB)           | ~€5-10/mo         |
| Hetzner CX23 VPS (Core — Docker Compose)             | ~€4/mo            |
| Hetzner CPX41 VPS (Workload — k3s)                   | ~€26/mo           |
| Forge S3 object storage (`photos`/`media`/`archive`) | TBD (usage-based) |
| Hetzner BX11 Storage Box (1 TB)                      | ~€4/mo            |
| Domains (4 × INWX, steady-state)                     | ~€6.30/mo         |
| Bitwarden Cloud (deployment creds, free tier)        | €0/mo             |
| Infisical Cloud (app secrets, free tier)             | €0/mo             |
| Terraform Cloud (state backend, free tier)           | €0/mo             |
| **Total**                                            | **~€64-80/mo**    |
