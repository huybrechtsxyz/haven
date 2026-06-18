# Haven Design and Architecture

> Decision date: 2026-05-26 — Solution A: Infomaniak kSuite + Hetzner VPS
> Scope: 5 users, family platform, EU/Swiss privacy, managed email, self-hosted apps.

---

## Design Goal

Simplest day-to-day experience for all 5 family members. A single Swiss vendor (Infomaniak) covers everything the family touches — email, files, docs, calendar, contacts. The VPS is invisible to the family; it runs Immich (photos), Vaultwarden (passwords), Infisical (secrets & config), Authentik (SSO), and home-grown apps.

---

## Architecture Reference

For system topology, component inventory, node specifications, and data durability model, see **[architecture.md](architecture.md)**.

---

## Domain & Email Layout

```
primary:   huybrechts.xyz   → kSuite MX → 5 mailboxes (one per family member)
alias 1:   huybrechts.dev   → kSuite MX → alias → primary mailboxes
alias 2:   alderwyn.xyz     → kSuite MX → alias → primary mailboxes
alias 3:   meeus.family     → kSuite MX → alias → primary mailboxes
static:    madebyjana.be    → Caddy static site (daughter's website)
decom:     theorderoftheblacklizard.be → NOT transferred; let expire at current registrar
```

All remaining domains are registered at **INWX**. `madebyjana.be` is hosted as a static site via Caddy on the VPS — it does not carry email.

### INWX domain pricing

| Domain                              | TLD       | Renew                     | Notes                            |
| ----------------------------------- | --------- | ------------------------- | -------------------------------- |
| `huybrechts.xyz`                    | `.xyz`    | ~€24/yr                   | flat                             |
| `alderwyn.xyz`                      | `.xyz`    | ~€24/yr                   | flat                             |
| `huybrechts.dev`                    | `.dev`    | ~€18/yr                   | HSTS-preloaded — HTTPS mandatory |
| `madebyjana.be`                     | `.be`     | ~€10/yr                   | no WHOIS privacy on .be          |
| `meeus.family`                      | `.family` | ~€50/yr*                  | *confirm pricing at INWX         |
| ~~`theorderoftheblacklizard.be`~~   | ~~`.be`~~ | —                         | decommissioned                   |
| **Total (steady-state, 5 domains)** |           | **~€126/yr (~€10.50/mo)** |                                  |

> **Note on `.dev`:** all `.dev` domains are HSTS-preloaded — HTTPS is mandatory. Caddy handles this automatically via auto-TLS.

### Mailboxes

Five kSuite mailboxes on `huybrechts.xyz`, one per family member. Replace placeholders once provisioned.

| Mailbox                  | Member | Notes                                 |
| ------------------------ | ------ | ------------------------------------- |
| `parent1@huybrechts.xyz` | Parent |                                       |
| `parent2@huybrechts.xyz` | Parent |                                       |
| `kid1@huybrechts.xyz`    | Child  | server-side copy forwarded to parents |
| `kid2@huybrechts.xyz`    | Child  | server-side copy forwarded to parents |
| `kid3@huybrechts.xyz`    | Child  | server-side copy forwarded to parents |

### Distribution groups

Configured in kSuite Mail Service → Distribution lists (no extra mailbox licence needed).

| Group address           | Members         | Purpose                   |
| ----------------------- | --------------- | ------------------------- |
| `family@huybrechts.xyz` | all 5 mailboxes | Family-wide announcements |

### Parental oversight — child mail forwarding

Each child's mailbox has a server-side **keep copy + forward** rule. Configured in: **kSuite Manager → Mail Service → [child mailbox] → Redirections / Forwarding**

| Child mailbox         | Forward copy to                                    |
| --------------------- | -------------------------------------------------- |
| `kid1@huybrechts.xyz` | `parent1@huybrechts.xyz`, `parent2@huybrechts.xyz` |
| `kid2@huybrechts.xyz` | `parent1@huybrechts.xyz`, `parent2@huybrechts.xyz` |
| `kid3@huybrechts.xyz` | `parent1@huybrechts.xyz`, `parent2@huybrechts.xyz` |

---

## Design Decisions & Security Posture

See [architecture.md](architecture.md) for infrastructure specifications, data durability model, and component inventory.

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
| Infisical         | Runs on Core VPS; admin UI behind Caddy + Authentik SSO (admin-only); API internal to Core VPS; secrets never in plain env files or git; Workload VPS accesses via ESO token scoped to its own namespace                                                                                                                                                                                                    |
| Container updates | Core VPS: image tags pinned in `haven`; `docker compose pull && up -d`; monthly review. Workload VPS: Helm versions pinned in `haven`; `helm upgrade`; Dependabot on `haven` for digest updates                                                                                                                                                                                                             |
| IaC secrets       | Core bootstrap: GitHub Secrets (Hetzner API key, SSH key) — one-time only; runtime uses Infisical. Workload VPS: Infisical ESO token only — no other secrets in workload pipelines                                                                                                                                                                                                                          |
| Monitoring        | Gatus (VPS) for per-service health; Healthchecks.io for BorgBackup dead-man's switch; UptimeRobot for external endpoint pings                                                                                                                                                                                                                                                                               |
| Backups           | Two-tier strategy: **Tier 1** — BorgBackup (Hearth + Forge) daily to Storage Box BX11 (encrypted, repokey-blake2); Jellyfin media on Storage Box (NFS, always present). **Tier 2** — daily rclone sync of entire Storage Box + S3 buckets (`haven-photos`, `haven-media`, `haven-archive`, `haven-docs`) to Infomaniak kDrive 3 TB (~03:00 UTC). Borg encryption key in Vaultwarden; restore tested monthly |

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
| **Total**                                            | **~€64-80/mo**    |
| **Previous spend**                                   | ~€58-81/mo        |

Savings: Bitwarden Team (~€15/mo) eliminated. 2 extra users added vs current Google Workspace (3 → 5). Swiss privacy. No MTA ops.

---

## Deployment Guide

### Prerequisites

| Tool                 | Version | Install                                                                              |
| -------------------- | ------- | ------------------------------------------------------------------------------------ |
| strata               | v0.0.4+ | `uv tool install xyz-strata` or `pip install xyz-strata`                             |
| OpenTofu / Terraform | >= 1.6  | [opentofu.org](https://opentofu.org/docs/intro/install/) or `choco install opentofu` |
| Ansible              | >= 2.14 | `pip install ansible-core`                                                           |
| GitHub CLI           | latest  | `winget install GitHub.cli`                                                          |

### Accounts Required

| Service         | What you need                                               | Where                                                  |
| --------------- | ----------------------------------------------------------- | ------------------------------------------------------ |
| Hetzner Cloud   | Project `haven` + API token (read/write)                    | [console.hetzner.cloud](https://console.hetzner.cloud) |
| Hetzner Robot   | Storage Box order (manual, no API)                          | [robot.hetzner.com](https://robot.hetzner.com)         |
| Terraform Cloud | Organization `huybrechts-xyz`, workspace `haven_deploy_prd` | [app.terraform.io](https://app.terraform.io)           |
| GitHub          | Repository secrets configured                               | Settings → Secrets → Actions                           |
| INWX            | Domain registrar                                            | [my.inwx.de](https://my.inwx.de)                       |

### Step 1 — Generate SSH Key Pair

**Option A — Bitwarden (recommended):**

1. In Bitwarden: Add item → SSH Key → Generate ed25519 key
2. Bitwarden's SSH agent will serve the key locally (no `~/.ssh/` file needed)
3. Export the public and private key values for GitHub Secrets

**Option B — Local key file:**

```bash
ssh-keygen -t ed25519 -C "haven-deploy" -f ~/.ssh/haven_ed25519 -N ""
```

### Step 2 — Configure GitHub Secrets

Go to repo → Settings → Secrets and variables → Actions. Add:

| Secret name             | Value                                              |
| ----------------------- | -------------------------------------------------- |
| `TERRAFORM_API_TOKEN`   | Terraform Cloud API token                          |
| `HETZNER_API_TOKEN`     | Hetzner Cloud project API token                    |
| `HETZNER_PUBLIC_KEY`    | SSH public key                                     |
| `HETZNER_PRIVATE_KEY`   | SSH private key                                    |
| `HETZNER_ROOT_PASSWORD` | Strong random password (initial provisioning only) |
| `INFISICAL_ESO_TOKEN`   | Leave empty for Wave 1 (needed for Workload VPS)   |

### Step 3 — Configure Terraform Cloud

1. Create organization `huybrechts-xyz`
2. Create workspace `haven_deploy_prd` (must match deployment name in strata config)
3. Set execution mode to **Local** (CLI drives the runs, TF Cloud stores state only)
4. Generate API token → use as `TERRAFORM_API_TOKEN` GitHub Secret

### Step 4 — Create Hetzner Cloud Project

1. Log in to Hetzner Cloud Console
2. Create project: `haven`
3. Go to Security → API Tokens → Generate token (read/write) → use as `HETZNER_API_TOKEN`

### Step 5 — Order Storage Box (Manual)

> **⚠️ Entirely manual.** Hetzner Storage Boxes are managed through Hetzner Robot — no API, no CLI, no Terraform provider.

1. Go to [robot.hetzner.com](https://robot.hetzner.com) → Storage Box
2. Order **BX11** (1 TB, ~€3.81/mo), location: **Nuremberg**
3. Create sub-accounts: `hearth_backup` (Core VPS) and `forge_backup` (Workload VPS)
4. Enable **SSH access** on both sub-accounts
5. Note hostname (e.g. `uXXXXXX.your-storagebox.de`) — needed for Ansible bootstrap

### Step 5b — Provision S3 Buckets (Ansible)

Four S3-compatible buckets are provisioned by the `deploy-infra.yml` workflow via `ansible-s3/forge-s3.yml`:

- `haven-photos` — Immich external library
- `haven-media` — media overflow
- `haven-archive` — cold storage
- `haven-docs` — documentation & exports

Credentials: Create one Hetzner Object Storage access key pair in the Cloud Console; both `HETZNER_S3_ACCESS_KEY` and `HETZNER_S3_SECRET_KEY` grant project-wide access to all buckets. Store in GitHub Secrets.

After provisioning, configure scheduled replication/sync from all four buckets to dedicated Infomaniak kDrive 3 TB via rclone (future: scripted in Forge config).

### Step 6 — Workflows: Infrastructure, Config, Deploy

Haven uses **three independent workflows**, each for a specific phase:

#### Workflow 1: `deploy-infra.yml`

Provisioning (rare, run once). No SSH needed.

**Inputs:** `branch`, `dry_run`, `stage`, `run_s3`

**Steps:** validate → build → terraform (strata) → S3 buckets (Ansible)

**Run in GitHub Actions:**

```
Actions → "Infra - haven" → Run workflow
  branch: <your-branch>
  dry_run: false
  stage: (leave empty for all)
  run_s3: true
```

After apply, note from Terraform output:

- `hearth_public_ip` — point DNS here
- `forge_public_ip` — internal address for now

#### Workflow 2: `deploy-hearth.yml`

Core VPS (Docker Compose) — init, config, deploy. Runs on-demand.

**Inputs:** `branch`, `dry_run`, `run_init`, `configure_borg`, `run_config`, `run_deploy`, `full_restart`, `backup_before_deploy`

**Run in GitHub Actions (after infra):**

```
Actions → "Hearth - haven" → Run workflow
  branch: <your-branch>
  dry_run: false
  run_init: true
  configure_borg: false  (run this once init completes and you authorize the SSH key in Hetzner Robot)
  run_config: true
  run_deploy: true
```

#### Workflow 3: `deploy-forge.yml`

Workload VPS (k3s) — init, config, deploy. Independent of Hearth.

**Inputs:** `branch`, `dry_run`, `run_init`, `configure_borg`, `configure_nfs`, `run_config`, `run_deploy`

**Run in GitHub Actions (after infra + Hearth init):**

```
Actions → "Forge - haven" → Run workflow
  branch: <your-branch>
  dry_run: false
  run_init: true
  configure_borg: false  (same SSH key authorization flow as Hearth)
  configure_nfs: true    (mounts Storage Box NFS at /mnt/storagebox)
  run_config: true
  run_deploy: true
```

**Recommended full deployment order:**

1. `deploy-infra.yml` (terraform + S3) — run once
2. Configure DNS: A records → `hearth_public_ip`
3. `deploy-hearth.yml` (init, config, deploy) — run full
4. Authorize Hearth Borg SSH key in Hetzner Robot
5. `deploy-hearth.yml` (run_init + configure_borg) — re-run to init BorgBackup
6. `deploy-forge.yml` (init, config, deploy) — run full
7. Authorize Forge Borg SSH key in Hetzner Robot (if using Borg on Forge)
8. `deploy-forge.yml` (run_init + configure_borg) — re-run to init Forge BorgBackup

### Step 7 — Configure DNS

In INWX, create A records pointing to `hearth_public_ip` from Terraform output:

| Record                   | Value                |
| ------------------------ | -------------------- |
| `huybrechts.xyz`         | `<hearth_public_ip>` |
| `auth.huybrechts.xyz`    | `<hearth_public_ip>` |
| `vault.huybrechts.xyz`   | `<hearth_public_ip>` |
| `secrets.huybrechts.xyz` | `<hearth_public_ip>` |
| `status.huybrechts.xyz`  | `<hearth_public_ip>` |
| `photos.huybrechts.xyz`  | `<hearth_public_ip>` |

TTL: 300 initially, increase to 3600 after verification.

The workflows handle all Ansible provisioning automatically — **no manual playbook runs needed**.

The playbook: installs Docker + Docker Compose, deploys Caddy + Authentik + Vaultwarden + Infisical, configures auto-TLS, sets up BorgBackup to Storage Box.

### Step 9 — Verify

- [ ] `https://huybrechts.xyz` — Caddy responds
- [ ] `https://auth.huybrechts.xyz` — Authentik login page
- [ ] `https://vault.huybrechts.xyz` — Vaultwarden web vault
- [ ] `https://secrets.huybrechts.xyz` — Infisical dashboard
- [ ] S3 buckets `photos`, `media`, `archive` exist and are writable
- [ ] Replication from S3 buckets to Infomaniak kDrive completed at least once
- [ ] SSH via private network only (public SSH blocked by firewall)
- [ ] BorgBackup cron runs successfully

### Step 10 — Enable CI/CD

Once manual deployment works:

1. Push to `main` — the workflow triggers automatically
2. Or run manually: Actions → Deploy Haven → Run workflow
3. Use `dry_run=true` for plan-only runs

### Architecture Reference

```
┌─────────────────────────────────────────────────────────┐
│ GitHub Actions (.github/workflows/deploy.yml)           │
│                                                         │
│  strata build → *.auto.tfvars.json                      │
│  strata deploy → terraform apply + ansible-playbook     │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│ Hetzner Cloud (huybrechts-family project)               │
│                                                         │
│  ┌─────────────┐    10.0.1.0/24     ┌──────────────┐   │
│  │   Hearth    │◄──────────────────►│    Forge     │   │
│  │   CX23      │   private net      │    CPX41     │   │
│  │             │                    │   (Wave 2)   │   │
│  │ Caddy       │                    │ k3s          │   │
│  │ Authentik   │                    │ Immich       │   │
│  │ Vaultwarden │                    │ Gatus        │   │
│  │ Infisical   │                    │              │   │
│  └──────┬──────┘                    └──────────────┘   │
│         │                                               │
│         │ SSH/BorgBackup                                │
│         ▼                                               │
│  ┌─────────────┐                                        │
│  │ Storage Box │ BX11, 1TB                              │
│  │ (BorgBackup)│                                        │
│  └─────────────┘                                        │
└─────────────────────────────────────────────────────────┘
```

---

## Migration

For the complete migration plan, checklists, and progress tracking, see **[migration.md](migration.md)**.

