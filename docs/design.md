# Haven Design and Architecture

> Decision date: 2026-05-26 — Solution A: Infomaniak kSuite + Hetzner VPS
> Scope: 5 users, family platform, EU/Swiss privacy, managed email, self-hosted apps.

---

## Design Goal

Simplest day-to-day experience for all 5 family members. A single Swiss vendor (Infomaniak) covers everything the family touches — email, files, docs, calendar, contacts. The VPS is invisible to the family; it runs Immich (photos), Vaultwarden (passwords), Infisical (secrets & config), Authentik (SSO), and home-grown apps.

---

## Architecture

```mermaid
graph TB
    subgraph Users["👨‍👩‍👧‍👦 Family Members (5)"]
        direction LR
        Browser[Web Browser]
        Mobile[iOS / Android]
        Desktop[Desktop Apps]
    end

    subgraph Infomaniak["☁️ Infomaniak kSuite — Switzerland 🇨🇭"]
        kMail[kMail<br/>Email + Webmail]
        kDrive[kDrive<br/>File Sync 3-6 TB]
        OnlyOffice_k[OnlyOffice<br/>Docs / Sheets / Slides]
        Calendar[Calendar<br/>CalDAV]
        Contacts[Contacts<br/>CardDAV]
    end

    subgraph CoreVPS["🛡️ Core VPS — Hetzner CX23 🇩🇪 (Docker Compose)"]
        Caddy[Caddy<br/>Reverse Proxy + TLS]
        Authentik[Authentik<br/>Identity / SSO / 2FA]
        Vaultwarden[Vaultwarden<br/>Password Manager]
        Infisical[Infisical<br/>Secrets & App Config]
    end

    subgraph WorkloadVPS["⚙️ Workload VPS — Hetzner CPX41 🇩🇪 (k3s)"]
        Immich[Immich<br/>Photo Management]
        Gatus[Gatus<br/>Health Dashboard]
        Apps[Home-grown Apps<br/>Helm / Docker]
    end

    subgraph ObjectStorage["🪣 Forge S3 Object Storage — S3 compatible"]
        S3Photos[Bucket: photos]
        S3Media[Bucket: media]
        S3Archive[Bucket: archive]
    end

    subgraph Storage["💾 Hetzner Storage Box BX11 — Germany 🇩🇪"]
        BorgBackup[BorgBackup<br/>Encrypted Daily Backups<br/>(Hearth + Forge)]
        MediaFiles[Jellyfin Media Library<br/>(NFS mount)]
    end

    subgraph DNS["🌐 INWX — Germany 🇩🇪"]
        DNSZones[DNS Zones<br/>MX / SPF / DKIM / DMARC<br/>A / CNAME]
    end

    subgraph GitHub["🐙 GitHub Actions (strata + haven)"]
        IaC[OpenTofu + Ansible + Helm]
    end

    %% User connections
    Users -->|HTTPS| Infomaniak
    Users -->|HTTPS| Caddy
    Mobile -->|Auto-upload| Immich

    %% Core VPS
    Caddy --> Authentik
    Caddy --> Vaultwarden
    Caddy --> Infisical
    Caddy -->|proxy| WorkloadVPS
    WorkloadVPS -->|read/write| ObjectStorage
    Authentik -.->|OIDC SSO| Immich
    Authentik -.->|OIDC SSO| Apps
    Infisical -.->|ESO token| WorkloadVPS

    %% Backup — tier 1: BorgBackup → Storage Box
    CoreVPS -->|BorgBackup daily| Storage
    WorkloadVPS -->|BorgBackup daily| Storage
    %% Backup — tier 2: Storage Box + S3 → kDrive (daily offsite sync)
    Storage -->|daily rclone sync| kDrive
    ObjectStorage -->|daily rclone sync| kDrive

    %% IaC
    GitHub -->|GitHub Secrets bootstrap| CoreVPS
    GitHub -->|Infisical token only| WorkloadVPS

    %% DNS
    DNSZones -->|MX records| Infomaniak
    DNSZones -->|A/CNAME| Caddy
```

---

## Components

| Layer              | Service                  | Provider                                                          | Purpose                                                                                                                                                                                    |
| ------------------ | ------------------------ | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Email              | kSuite Mail              | Infomaniak (CH 🇨🇭)                                                | 5 mailboxes, custom domains, alias forwarding, CalDAV/CardDAV, ActiveSync                                                                                                                  |
| Calendar           | kSuite Calendar          | Infomaniak (CH 🇨🇭)                                                | Shared family calendars, delegation, CalDAV, iOS/Android sync                                                                                                                              |
| Contacts           | kSuite Contacts          | Infomaniak (CH 🇨🇭)                                                | CardDAV, vCard import/export, mobile sync                                                                                                                                                  |
| Files              | kDrive                   | Infomaniak (CH 🇨🇭)                                                | 3–6 TB shared storage, desktop/mobile apps, versioning                                                                                                                                     |
| Docs               | OnlyOffice (via kDrive)  | Infomaniak (CH 🇨🇭)                                                | Docs/Sheets/Slides in browser                                                                                                                                                              |
| Photos             | Immich                   | Hetzner VPS (DE 🇩🇪)                                               | Timeline, face recognition, shared albums, mobile auto-upload; originals stored in S3 `photos` bucket — S3 is first-class in Immich, survives cluster rebuild, scales without resizing |
| Media streaming    | Jellyfin                 | Hetzner CPX41 VPS (DE 🇩🇪)                                         | Open-source Plex alternative; no account required; OIDC via Authentik; library stored on Storage Box (NFS mount) — fixed cost, low latency, sequential reads |
| Media overflow     | S3 bucket `media`        | Forge side (S3 compatible)                                         | Secondary overflow for large binary assets if Storage Box fills; not primary media path |
| Archive            | S3 bucket `archive`      | Forge side (S3 compatible)                                         | Documents, exports, cold storage, long-term retention |
| Passwords          | Vaultwarden              | Hetzner VPS (DE 🇩🇪)                                               | Bitwarden-compatible; same Firefox extension + iPhone app for family                                                                                                                       |
| Secrets & config   | Infisical                | Hetzner VPS (DE 🇩🇪)                                               | Per-app/env secrets + key-value config; CLI/SDK; replaces App Config/Consul                                                                                                                |
| Identity (SSO)     | Authentik                | Hetzner VPS (DE 🇩🇪)                                               | OIDC/OAuth2 for all VPS services; 2FA enforcement; user lifecycle                                                                                                                          |
| Compute — Core     | Docker Compose           | Hetzner CX23 VPS (DE 🇩🇪)                                          | Authentik, Vaultwarden, Infisical, Caddy — stable core; bootstrapped via GitHub Secrets; never experiments run here                                                                        |
| Compute — Workload | k3s (single-node)        | Hetzner CPX41 VPS (DE 🇩🇪)                                         | Immich, Gatus, home-grown apps via Helm; expendable — destroy/rebuild freely; secrets via Infisical token only (External Secrets Operator)                                                 |
| IaC — tool         | strata (Python CLI)      | [`huybrechtsxyz/strata`](https://github.com/huybrechtsxyz/strata) | Own Terragrunt alternative; orchestrates OpenTofu + Ansible against `haven` config                                                                                                         |
| IaC — config       | haven (config repo)      | [`huybrechtsxyz/haven`](https://github.com/huybrechtsxyz/haven)   | All infra + app declarations: OpenTofu .tf, Ansible vars, Docker Compose, Helm values                                                                                                      |
| Reverse proxy      | Caddy                    | Hetzner VPS (DE 🇩🇪)                                               | Automatic Let's Encrypt TLS, HSTS, subdomain routing                                                                                                                                       |
| Backups            | Two-tier backups         | Hetzner + Infomaniak                                               | **Tier 1:** Hearth + Forge system state via BorgBackup → Storage Box BX11 (daily, encrypted). **Tier 2:** Storage Box + S3 buckets (`photos`, `media`, `archive`) synced to dedicated Infomaniak kDrive 3 TB once a day via rclone — offsite cross-provider copy |
| Monitoring         | Gatus + Healthchecks.io  | Hetzner VPS (DE 🇩🇪) + external                                    | Gatus on VPS: per-service health dashboard; Healthchecks.io (free): BorgBackup dead-man's switch; UptimeRobot: public endpoint availability                                                |
| DNS registration   | INWX                     | INWX (DE 🇩🇪)                                                      | Domain registration for 4 active domains                                                                                                                                                   |
| DNS hosting        | INWX built-in NS         | INWX (DE 🇩🇪)                                                      | MX, SPF, DKIM, DMARC, A/CNAME records per domain                                                                                                                                           |

---

## Domain & Email Layout

```
primary:   huybrechts.xyz   → kSuite MX → 5 mailboxes (one per family member)
alias 1:   huybrechts.dev   → kSuite MX → alias → primary mailboxes
alias 2:   alderwyn.xyz     → kSuite MX → alias → primary mailboxes
static:    madebyjana.be    → Caddy static site (daughter's website)
decom:     meeus.family     → NOT transferred; let expire at Versio (~€52/yr renewal not worth it)
decom:     theorderoftheblacklizard.be → NOT transferred; let expire at current registrar
```

All remaining domains are registered at **INWX**. `madebyjana.be` is hosted as a static site via Caddy on the VPS — it does not carry email.

### INWX domain pricing

| Domain                             | TLD       | Renew       | Notes                          |
| ---------------------------------- | --------- | ----------- | ------------------------------ |
| `huybrechts.xyz`                   | `.xyz`    | ~€24/yr     | flat                           |
| `alderwyn.xyz`                     | `.xyz`    | ~€24/yr     | flat                           |
| `huybrechts.dev`                   | `.dev`    | ~€18/yr     | HSTS-preloaded — HTTPS mandatory |
| `madebyjana.be`                    | `.be`     | ~€10/yr     | no WHOIS privacy on .be        |
| ~~`meeus.family`~~                 | ~~`.family`~~ | —       | decommissioned                 |
| **Total (steady-state, 4 domains)**|           | **~€76/yr (~€6.30/mo)** |               |

> **Note on `.dev`:** all `.dev` domains are HSTS-preloaded — HTTPS is mandatory. Caddy handles this automatically via auto-TLS.

### Mailboxes

Five kSuite mailboxes on `huybrechts.xyz`, one per family member. Replace placeholders once provisioned.

| Mailbox                  | Member | Notes                                  |
| ------------------------ | ------ | -------------------------------------- |
| `parent1@huybrechts.xyz` | Parent |                                        |
| `parent2@huybrechts.xyz` | Parent |                                        |
| `kid1@huybrechts.xyz`    | Child  | server-side copy forwarded to parents  |
| `kid2@huybrechts.xyz`    | Child  | server-side copy forwarded to parents  |
| `kid3@huybrechts.xyz`    | Child  | server-side copy forwarded to parents  |

### Distribution groups

Configured in kSuite Mail Service → Distribution lists (no extra mailbox licence needed).

| Group address           | Members         | Purpose                      |
| ----------------------- | --------------- | ---------------------------- |
| `family@huybrechts.xyz` | all 5 mailboxes | Family-wide announcements    |

### Parental oversight — child mail forwarding

Each child's mailbox has a server-side **keep copy + forward** rule. Configured in: **kSuite Manager → Mail Service → [child mailbox] → Redirections / Forwarding**

| Child mailbox         | Forward copy to                                    |
| --------------------- | -------------------------------------------------- |
| `kid1@huybrechts.xyz` | `parent1@huybrechts.xyz`, `parent2@huybrechts.xyz` |
| `kid2@huybrechts.xyz` | `parent1@huybrechts.xyz`, `parent2@huybrechts.xyz` |
| `kid3@huybrechts.xyz` | `parent1@huybrechts.xyz`, `parent2@huybrechts.xyz` |

---

## VPS Specification

Two-node architecture: a stable **Core VPS** (never touched once running) and an expendable **Workload VPS** (tinker freely).

### Data Durability Model

Two-tier backup strategy — all data lands on the Storage Box first, then syncs offsite to Infomaniak kDrive:

```
Tier 1 — Daily BorgBackup (Hetzner-internal, fast)
  Hearth (Docker state, DB volumes, config)  ──┐
  Forge  (k3s state, app volumes, config)    ──┤──► Storage Box BX11 (1 TB)
  Jellyfin media library                     ──┘    (NFS mount, always present)

Tier 2 — Daily offsite sync (rclone, ~03:00 UTC)
  Storage Box BX11 (all contents)            ──┐
  S3 haven-photos                            ──┤──► Infomaniak kDrive (3 TB)
  S3 haven-media                             ──┤    cross-provider, Swiss datacentre
  S3 haven-archive                           ──┘
```

- The Forge cluster is treated as **ephemeral compute**: destroying and rebuilding it must not cause data loss.
- Three dedicated S3-compatible buckets:
  - `photos` — Immich external library (originals + derivatives); S3 is natively supported by Immich and survives cluster destruction
  - `media` — overflow for large binary assets if Storage Box capacity is exhausted
  - `archive` — documents, exports, cold storage, long-term retention
- Jellyfin media library is stored on the **Hetzner Storage Box (BX11)** via NFS mount — fixed cost, Hetzner-internal low-latency network, no per-GB egress, and already covered by the tier-2 sync
- Provider separation: primary on Hetzner (Storage Box + S3), offsite copy on Infomaniak (Swiss jurisdiction)

### Node 1 — Core VPS (Docker Compose) 🛡️

Runs identity and secrets infrastructure. Boring by design — deployed once, never used as a playground. If this node is healthy, you can always recover everything else.

| Spec          | Value                                                                       |
| ------------- | --------------------------------------------------------------------------- |
| Model         | Hetzner CX23                                                                |
| vCPU          | 2                                                                           |
| RAM           | 4 GB                                                                        |
| SSD           | 40 GB                                                                       |
| Network       | 20 TB/mo included                                                           |
| Orchestration | Docker Compose + systemd                                                    |
| Services      | Caddy, Authentik, Vaultwarden, Infisical                                    |
| Cost          | ~€4/mo                                                                      |
| IaC secrets   | **GitHub Secrets** (bootstrap only — acceptable; Infisical not running yet) |

**Bootstrap sequence:**

1. GitHub Actions uses GitHub Secrets (Hetzner API key, SSH key) to provision the CX23 via OpenTofu and run Ansible
2. Ansible deploys Docker Compose stack: Caddy → Infisical → Authentik → Vaultwarden
3. After Infisical is running, all subsequent deployments pull secrets from Infisical — GitHub Secrets no longer needed at runtime

### Node 2 — Workload VPS (k3s) ⚙️

Runs all family apps. Can be destroyed and rebuilt at any time without affecting core auth or passwords.

| Spec          | Value                                                                                        |
| ------------- | -------------------------------------------------------------------------------------------- |
| Model         | Hetzner CPX41                                                                                |
| vCPU          | 8                                                                                            |
| RAM           | 16 GB                                                                                        |
| SSD           | 240 GB                                                                                       |
| Network       | 20 TB/mo included                                                                            |
| Orchestration | k3s (single-node) + Helm + External Secrets Operator + cert-manager + Argo CD                |
| Services      | Immich (photos), Jellyfin (media streaming), Gatus (health), home-grown apps                 |
| Cost          | ~€26/mo                                                                                      |
| IaC secrets   | **Infisical token only** — no GitHub Secrets; ESO pulls all secrets at runtime from Core VPS |

**Secrets flow on Workload VPS:**

- GitHub Actions passes a single short-lived Infisical machine token to the k3s deployment
- External Secrets Operator (ESO) uses that token to fetch all app secrets from Infisical at runtime
- No secrets stored in git, no GitHub Secrets in workload pipelines, no plain env files

| Comparison point | Core VPS (Docker Compose)                | Workload VPS (k3s)               |
| ---------------- | ---------------------------------------- | -------------------------------- |
| Services         | Caddy, Authentik, Vaultwarden, Infisical | Immich, Jellyfin, Gatus, apps    |
| Stability goal   | Never breaks                             | Expendable — rebuild freely      |
| Secrets source   | GitHub Secrets (bootstrap only) → Infisical | Infisical token only (ESO)    |
| Upgrade strategy | `docker compose pull && up -d`           | `helm upgrade`, rolling restarts |
| Rollback         | Manual (image tags in Compose)           | `helm rollback`                  |
| Multi-node later | n/a                                      | Easy — add CPX31 worker node     |
| Cert management  | Caddy auto-TLS                           | cert-manager + Let's Encrypt     |
| Cost             | ~€4/mo                                   | ~€26/mo                          |

### Infrastructure as Code

| Tool       | Role                                                                                                                                | Repo                                                              |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| **strata** | Python CLI — orchestrates OpenTofu + Ansible + Helm runs against `haven` config                                                     | [`huybrechtsxyz/strata`](https://github.com/huybrechtsxyz/strata) |
| **haven**  | Config repo — YAML-based declarations of all infra and apps (OpenTofu `.tf`, Ansible vars, Docker Compose files, Helm values)       | [`huybrechtsxyz/haven`](https://github.com/huybrechtsxyz/haven)   |

---

## Security Posture

| Layer             | Controls                                                                                                                                                                                                                                               |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| kSuite            | Swiss nFADP + GDPR, DPA, TLS in transit, encrypted at rest, DKIM/DMARC managed; ⚠ no independent backup of kSuite data — relies on Infomaniak redundancy + 30-day kDrive versioning; consider periodic IMAP/CardDAV/CalDAV export to VPS for cold copy |
| VPS OS            | UFW (80/443/SSH only), SSH key-only, Fail2Ban, unattended-upgrades                                                                                                                                                                                     |
| Caddy             | Auto HTTPS, HSTS, TLS 1.2/1.3 only, HTTP/2                                                                                                                                                                                                            |
| Authentik         | 2FA enforced (TOTP/WebAuthn), OIDC provider for all services, daily encrypted DB backup                                                                                                                                                                |
| Vaultwarden       | HTTPS only, OIDC login via Authentik, admin token protected, daily backup                                                                                                                                                                              |
| Immich            | OIDC login via Authentik, not exposed without auth; originals stored in S3 `photos` bucket (Immich native S3 library support); replicated to Infomaniak kDrive                                                                                     |
| Jellyfin          | OIDC login via Authentik; library on Storage Box NFS mount (read-only from VPS); no originals on cluster SSD; software transcode only (no GPU)                                                                                                     |
| Infisical         | Runs on Core VPS; admin UI behind Caddy + Authentik SSO (admin-only); API internal to Core VPS; secrets never in plain env files or git; Workload VPS accesses via ESO token scoped to its own namespace                                               |
| Container updates | Core VPS: image tags pinned in `haven`; `docker compose pull && up -d`; monthly review. Workload VPS: Helm versions pinned in `haven`; `helm upgrade`; Dependabot on `haven` for digest updates                                                        |
| IaC secrets       | Core bootstrap: GitHub Secrets (Hetzner API key, SSH key) — one-time only; runtime uses Infisical. Workload VPS: Infisical ESO token only — no other secrets in workload pipelines                                                                     |
| Monitoring        | Gatus (VPS) for per-service health; Healthchecks.io for BorgBackup dead-man's switch; UptimeRobot for external endpoint pings                                                                                                                          |
| Backups           | Two-tier strategy: **Tier 1** — BorgBackup (Hearth + Forge) daily to Storage Box BX11 (encrypted, repokey-blake2); Jellyfin media on Storage Box (NFS, always present). **Tier 2** — daily rclone sync of entire Storage Box + S3 buckets (`photos`, `media`, `archive`) to Infomaniak kDrive 3 TB (~03:00 UTC). Borg encryption key in Vaultwarden; restore tested monthly |

---

## Monthly Cost

| Item                                       | Cost           |
| ------------------------------------------ | -------------- |
| Infomaniak kSuite (5 users, kDrive 3 TB)   | ~€25-35/mo     |
| Infomaniak kDrive extra storage (to ~5 TB) | ~€5-10/mo      |
| Hetzner CX23 VPS (Core — Docker Compose)   | ~€4/mo         |
| Hetzner CPX41 VPS (Workload — k3s)         | ~€26/mo        |
| Forge S3 object storage (`photos`/`media`/`archive`) | TBD (usage-based) |
| Hetzner BX11 Storage Box (1 TB)            | ~€4/mo         |
| Domains (4 × INWX, steady-state)           | ~€6.30/mo      |
| **Total**                                  | **~€64-80/mo** |
| **Previous spend**                         | ~€58-81/mo     |

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

| Secret name             | Value                                               |
| ----------------------- | --------------------------------------------------- |
| `TERRAFORM_API_TOKEN`   | Terraform Cloud API token                           |
| `HETZNER_API_TOKEN`     | Hetzner Cloud project API token                     |
| `HETZNER_PUBLIC_KEY`    | SSH public key                                      |
| `HETZNER_PRIVATE_KEY`   | SSH private key                                     |
| `HETZNER_ROOT_PASSWORD` | Strong random password (initial provisioning only)  |
| `INFISICAL_ESO_TOKEN`   | Leave empty for Wave 1 (needed for Workload VPS)    |

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

### Step 5b — Create S3 Buckets (Forge side)

Create three S3-compatible buckets used by workloads:

- `photos`
- `media`
- `archive`

Then configure scheduled replication/sync from all three buckets to dedicated Infomaniak kDrive 3 TB.

### Step 6 — Initial Deployment (Local)

```powershell
cd e:\SourcesXYZ\haven

# Authenticate Terraform Cloud
terraform login

# Build strata artifacts
strata build run -f config/deploy-haven-prd.yaml

# Copy tfvars
Copy-Item build\haven_deploy_prd-1.0.0\terraform\*.auto.tfvars.json terraform\

# Export secrets
$env:TF_VAR_HETZNER_API_TOKEN = "your-token"
$env:TF_VAR_HETZNER_PUBLIC_KEY = Get-Content ~/.ssh/haven_ed25519.pub
$env:TF_VAR_HETZNER_PRIVATE_KEY = Get-Content ~/.ssh/haven_ed25519 -Raw
$env:TF_VAR_HETZNER_ROOT_PASSWORD = "your-password"
$env:TF_VAR_INFISICAL_ESO_TOKEN = ""

# Init + Plan + Apply
cd terraform
terraform init
terraform plan
terraform apply
```

After apply, note:

- `hearth_public_ip` — point DNS here
- `hearth_private_ip` — internal network address

### Step 7 — Configure DNS

In INWX, create A records pointing to VPS IP:

| Record                   | Value                  |
| ------------------------ | ---------------------- |
| `huybrechts.xyz`         | `<hearth_public_ip>`   |
| `auth.huybrechts.xyz`    | `<hearth_public_ip>`   |
| `vault.huybrechts.xyz`   | `<hearth_public_ip>`   |
| `secrets.huybrechts.xyz` | `<hearth_public_ip>`   |
| `status.huybrechts.xyz`  | `<hearth_public_ip>`   |
| `photos.huybrechts.xyz`  | `<hearth_public_ip>`   |

TTL: 300 initially, increase to 3600 after verification.

### Step 8 — Bootstrap Core VPS (Ansible)

```bash
ansible-playbook -i <hearth_public_ip>, deploy/ansible/hearth-bootstrap.yml \
  --private-key ~/.ssh/haven_ed25519 \
  -u root
```

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

**Strategy: Two-wave gradual migration.** Wave 1 migrates developer/infrastructure services (VPS, passwords, secrets, photos) while Google Workspace stays active. Wave 2 migrates email, files, calendar, and contacts to kSuite after Wave 1 is proven stable.

**Why gradual?** VPS services only affect the admin (low blast radius). Google Workspace email affects the whole family daily (highest risk, migrate last). Domains were transferred early; MX stays on Google until Wave 2 cutover.

### Accounts & Access

| Service         | URL                              | Username                   | Credentials stored                          |
| --------------- | -------------------------------- | -------------------------- | ------------------------------------------- |
| INWX            | <https://www.inwx.de>            | `vincent@huybrechts.xyz`   | Bitwarden (migrate to Vaultwarden → Family) |
| Hetzner         | <https://console.hetzner.cloud>  | `vincent@huybrechts.xyz`   | Bitwarden (migrate to Vaultwarden → Family) |
| Infomaniak      | <https://manager.infomaniak.com> | `vincent@huybrechts.xyz`   | Vaultwarden → Family                        |
| Healthchecks.io | <https://healthchecks.io>        | `vincent@huybrechts.xyz`   | Vaultwarden → Family                        |
| UptimeRobot     | <https://uptimerobot.com>        | `vincent@huybrechts.xyz`   | Vaultwarden → Family                        |

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

| Type | Name                             | Priority | Value                                                           | TTL   |
| ---- | -------------------------------- | -------- | --------------------------------------------------------------- | ----- |
| A    | huybrechts.xyz                   |          | 185.237.97.232                                                  | 3600  |
| A    | <www.huybrechts.xyz>               |          | 185.237.97.232                                                  | 3600  |
| MX   | huybrechts.xyz                   | 1        | ASPMX.L.GOOGLE.COM                                              | 14400 |
| MX   | huybrechts.xyz                   | 5        | ALT1.ASPMX.L.GOOGLE.COM                                        | 14400 |
| MX   | huybrechts.xyz                   | 5        | ALT2.ASPMX.L.GOOGLE.COM                                        | 14400 |
| MX   | huybrechts.xyz                   | 10       | ALT3.ASPMX.L.GOOGLE.COM                                        | 14400 |
| MX   | huybrechts.xyz                   | 10       | ALT4.ASPMX.L.GOOGLE.COM                                        | 14400 |
| TXT  | huybrechts.xyz                   |          | v=spf1 include:_spf.google.com ~all                            | 14400 |
| TXT  | google._domainkey.huybrechts.xyz |          | v=DKIM1; k=rsa; p=MIIBIjAN… *(full key in INWX)*              | 14400 |
| CAA  | huybrechts.xyz                   |          | 128 issue "letsencrypt.org"                                     | 14400 |

**huybrechts.dev** (was at Versio):

| Type | Name              | Priority | Value                                  | TTL   |
| ---- | ----------------- | -------- | -------------------------------------- | ----- |
| A    | huybrechts.dev    |          | 185.47.174.65                          | 3600  |
| MX   | huybrechts.dev    | 1        | ASPMX.L.GOOGLE.COM                    | 14400 |
| MX   | huybrechts.dev    | 5        | ALT1.ASPMX.L.GOOGLE.COM               | 14400 |
| MX   | huybrechts.dev    | 5        | ALT2.ASPMX.L.GOOGLE.COM               | 14400 |
| MX   | huybrechts.dev    | 10       | ALT3.ASPMX.L.GOOGLE.COM               | 14400 |
| MX   | huybrechts.dev    | 10       | ALT4.ASPMX.L.GOOGLE.COM               | 14400 |
| TXT  | huybrechts.dev    |          | v=spf1 a mx ip4:185.182.56.120 …      | 14400 |
| TXT  | huybrechts.dev    |          | google-site-verification=bTxhh5aX4…   | 14400 |
| CAA  | huybrechts.dev    |          | 0 issue "letsencrypt.org"              | 3600  |

#### Transfer steps

| #     | Task                                                                     | Result / Notes                                                                                                                          | Done |
| ----- | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- | ---- |
| 1     | Unlock `huybrechts.xyz` at Versio                                        | ✓ 2026-05-27                                                                                                                            | [x]  |
| 2     | Unlock `huybrechts.dev` at Versio                                        | ✓ 2026-05-27                                                                                                                            | [x]  |
| ~~3~~ | ~~Unlock `meeus.family` at Versio~~                                      | ✗ decommissioned                                                                                                                        | —    |
| 4     | Contact ClouDNS — unlock `alderwyn.xyz` + `madebyjana.be`, get EPP codes | ✓ 2026-05-27 — tickets submitted                                                                                                        | [x]  |
| 5     | Request EPP code for `huybrechts.xyz` at Versio                          | ✓ 2026-05-27                                                                                                                            | [x]  |
| 6     | Request EPP code for `huybrechts.dev` at Versio                          | ✓ 2026-05-27                                                                                                                            | [x]  |
| 7     | Receive EPP codes from ClouDNS                                           | `alderwyn.xyz` ✓ · `madebyjana.be` ✓ (.be uses DNS.be email confirmation, no EPP)                                                      | [x]  |
| 8     | Initiate transfers at INWX                                               | All 4 started 2026-05-27                                                                                                                | [x]  |
| 9     | Approve confirmation emails                                              | ✓ 2026-06-01                                                                                                                            | [x]  |
| 10    | Confirm all 4 domains in INWX panel                                      | ✓ 2026-06-02 — NS switched to `ns1/ns2/ns3.inwx.de`                                                                                    | [x]  |
| 11    | Recreate DNS records at INWX identically                                 | ✓ 2026-06-02 — MX/A/TXT/DKIM/CAA all added; DNSSEC not configured; transient validation error during NS propagation, resolved | [x]  |
| 12    | Enable WHOIS privacy                                                     | `alderwyn.xyz` ✓ · `huybrechts.xyz` ✓ · `huybrechts.dev` ✓ · `.be` does not support WHOIS privacy                                     | [x]  |
| 13    | Send test email — verify mail still works                                | ✓ 2026-06-02 — test email received from work address                                                                                    | [x]  |

#### Domain expiry dates after transfer

| Domain             | Expiry at INWX                               |
| ------------------ | -------------------------------------------- |
| `huybrechts.xyz`   | 2027-10-04                                   |
| `huybrechts.dev`   | *(fill in)*                                  |
| `alderwyn.xyz`     | *(fill in from INWX panel)*                  |
| `madebyjana.be`    | *(fill in)*                                  |
| ~~`meeus.family`~~ | ✗ decommissioned — not transferred           |

---

### Phase 1.2 — Provision Hetzner VPS + Storage Box

**Status:** 🟡 In progress

#### Steps

| #   | Task                                        | Result / Notes               | Done |
| --- | ------------------------------------------- | ---------------------------- | ---- |
| 1   | Create Hetzner project `huybrechts-family`  |                              | [ ]  |
| 2   | Provision CX23 VPS (Core)                   | Region: ___________          | [ ]  |
| 3   | Provision BX11 Storage Box                  | Region: ___________          | [ ]  |
| 4   | Add SSH public key to VPS                   | Key fingerprint: ___________ | [ ]  |
| 5   | Create S3 buckets `photos`, `media`, `archive` | Provider/project: ________ | [ ]  |
| 6   | Configure replication S3 → Infomaniak kDrive | Job/tool: ___________      | [ ]  |
| 7   | Run `strata` bootstrap                      | Completed: ___________       | [ ]  |
| 8   | Deploy Caddy                                |                              | [ ]  |
| 9   | Verify Caddy HTTPS on VPS IP                |                              | [ ]  |

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

| #   | Task                                                           | Result / Notes               | Done |
| --- | -------------------------------------------------------------- | ---------------------------- | ---- |
| 1   | Deploy Immich via Docker Compose                               |                              | [ ]  |
| 2   | Configure OIDC login via Authentik                             |                              | [ ]  |
| 3   | Export Google Photos via Takeout (original quality, all users) |                              | [ ]  |
| 4   | Upload photo library to Immich                                 | Photos imported: ___________ | [ ]  |
| 5   | Verify albums, dates, metadata preserved                       |                              | [ ]  |
| 6   | Install Immich mobile app on family phones (enable auto-upload)|                              | [ ]  |
| 7   | Confirm face recognition indexing completes                    |                              | [ ]  |

---

### Phase 1.7 — Backups & Monitoring

**Status:** 🔴 Not started

| #   | Task                                                             | Result / Notes              | Done |
| --- | ---------------------------------------------------------------- | --------------------------- | ---- |
| 1   | Configure BorgBackup cron (daily → Storage Box)                  | Encryption key in Vaultwarden | [ ] |
| 2   | Configure scheduled S3 replication (`photos`/`media`/`archive` → kDrive) | Tool/job: ___________   | [ ]  |
| 3   | Test full restore from BorgBackup                                |                              | [ ]  |
| 4   | Test restore from kDrive copy back into S3                       |                              | [ ]  |
| 5   | Deploy Gatus health checks (per-service endpoints)               |                              | [ ]  |
| 6   | Register Healthchecks.io dead-man's switch (backup alert)        |                              | [ ]  |
| 7   | Set up UptimeRobot for public endpoint monitoring                 |                              | [ ]  |

---

### Phase 1.8 — Decommission Kamatera + Bitwarden

> Only after all VPS services stable for 2+ weeks.

| #   | Task                                          | Result / Notes    | Done |
| --- | --------------------------------------------- | ----------------- | ---- |
| 1   | Verify no traffic/services still on Kamatera  |                   | [ ]  |
| 2   | Final backup of Kamatera data                 |                   | [ ]  |
| 3   | Decommission Kamatera VPS                     | Cancelled: _______ | [ ]  |
| 4   | Cancel Bitwarden Team subscription            | Cancelled: _______ | [ ]  |

#### Wave 1 cost impact

| Item removed        | Monthly saving |
| ------------------- | -------------- |
| Bitwarden Team      | ~€15/mo        |
| Kamatera VPS        | ~€20-40/mo     |
| **Total saving**    | **~€35-55/mo** |

| Item added              | Monthly cost |
| ----------------------- | ------------ |
| Hetzner CX23 VPS        | ~€4/mo       |
| Forge S3 object storage | TBD          |
| Hetzner BX11 Storage Box| ~€4/mo       |
| Domains (4 × INWX)      | ~€6.30/mo    |
| **Total new cost**      | **~€14/mo + S3 usage**  |

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

| #   | Task                                              | Notes                                       | Done |
| --- | ------------------------------------------------- | ------------------------------------------- | ---- |
| 1   | Create Infomaniak account (admin)                 |                                             | [ ]  |
| 2   | Export Gmail (all 3 users) — MBOX via Takeout     |                                             | [ ]  |
| 3   | Export Google Contacts (all 3 users) — vCard .vcf |                                             | [ ]  |
| 4   | Export Google Calendar (all 3 users) — ICS .ics   |                                             | [ ]  |
| 5   | Export Google Drive (all 3 users) — Takeout/rclone|                                             | [ ]  |
| 6   | Validate MBOX files (spot-check in Thunderbird)   | ✓                                           | [ ]  |
| 7   | Confirm vCard/ICS open correctly                  | ✓                                           | [ ]  |
| 8   | Confirm Drive export complete                     | ✓                                           | [ ]  |

### Phase 2.2 — Provision kSuite

**Status:** 🔴 Not started

| #     | Task                                                   | Result / Notes                           | Done |
| ----- | ------------------------------------------------------ | ---------------------------------------- | ---- |
| 1     | Purchase kSuite plan (5 users, kDrive 3 TB+)           | Plan: ___________ Cost: ___/mo           | [ ]  |
| 2     | Add + verify `huybrechts.xyz`                          | Verified: ___________                    | [ ]  |
| 3     | Add + verify `huybrechts.dev`                          | Verified: ___________                    | [ ]  |
| 4     | Add + verify `alderwyn.xyz`                            | Verified: ___________                    | [ ]  |
| ~~5~~ | ~~Add + verify `meeus.family`~~                        | ✗ decommissioned                         | —    |
| 6     | Create 5 mailboxes on `huybrechts.xyz`                 |                                          | [ ]  |
| 7     | Configure aliases across alias domains                 |                                          | [ ]  |
| 8     | Create `family@huybrechts.xyz` group (all 5)           |                                          | [ ]  |
| 9     | Configure child mail forwarding (child → both parents) |                                          | [ ]  |
| 10    | Generate DKIM keys per domain in kSuite                | Note DNS records for Phase 2.4           | [ ]  |

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

| #     | Task                                            | Time / Notes              | Done |
| ----- | ----------------------------------------------- | ------------------------- | ---- |
| 1     | Switch MX for `huybrechts.xyz`                  | Time: ___________         | [ ]  |
| 2     | Switch MX for `huybrechts.dev`                  | Time: ___________         | [ ]  |
| 3     | Switch MX for `alderwyn.xyz`                    | Time: ___________         | [ ]  |
| ~~4~~ | ~~Switch MX for `meeus.family`~~                | ✗ decommissioned          | —    |
| 5     | Update SPF for all 3 domains                    |                           | [ ]  |
| 6     | Add DKIM records for all 3 domains              |                           | [ ]  |
| 7     | Add DMARC records for all 3 domains             |                           | [ ]  |
| 8     | Send test email (external → each mailbox)       |                           | [ ]  |
| 9     | Send test email FROM each kSuite mailbox        |                           | [ ]  |
| 10    | Check headers: DKIM=pass, SPF=pass, DMARC=pass  |                           | [ ]  |
| 11    | Test child → parent forwarding                  |                           | [ ]  |
| 12    | Test `family@huybrechts.xyz` group              |                           | [ ]  |
| 13    | Monitor kSuite logs for 24h                     | No errors: ___________ | [ ]  |

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

| #   | Task                                                                  | Target date | Done |
| --- | --------------------------------------------------------------------- | ----------- | ---- |
| 1   | Raise DNS TTL back to 3600s (1 week after cutover)                    |             | [ ]  |
| 2   | DMARC `p=none` → `p=quarantine` (after 2 weeks, review `rua` reports) |             | [ ]  |
| 3   | DMARC `p=quarantine` → `p=reject` (after 4 weeks)                     |             | [ ]  |
| 4   | Set up monthly kSuite cold export to VPS (IMAP + CalDAV/CardDAV pull) |             | [ ]  |
| 5   | Write family runbook (password reset, add device, add alias)          |             | [ ]  |
| 6   | Share emergency access credentials with trusted person                |             | [ ]  |
| 7   | Schedule monthly maintenance window                                   | Day/time: ___________  | [ ]  |

---

### Migration Timeline

| Phase                          | Duration          | Notes                             |
| ------------------------------ | ----------------- | --------------------------------- |
| **Wave 1**                     |                   |                                   |
| 1.1 — Domain transfer          | ✅ done           |                                   |
| 1.2 — VPS provisioning         | 1–2 days          | In progress                       |
| 1.3 — Authentik                | 0.5 day           | After 1.2                         |
| 1.4 — Vaultwarden              | 0.5 day           | After 1.3                         |
| 1.5 — Infisical                | 0.5 day           | After 1.3                         |
| 1.6 — Immich                   | 1 day             | After 1.3                         |
| 1.7 — Backups & monitoring     | 0.5 day           | After 1.2                         |
| 1.8 — Decommission old         | After 2-week soak |                                   |
| **Wave 1 total**               | ~3 weeks (incl. soak) |                               |
| **Wave 2**                     |                   |                                   |
| 2.1 — Preparation              | 1–2 days          |                                   |
| 2.2 — kSuite provisioning      | 1 day             | After 2.1                         |
| 2.3 — Data migration           | 2–3 days          | After 2.2                         |
| 2.4 — DNS cutover              | 1 evening         | After 2.3                         |
| 2.5 — Client config            | 1–2 days          | After 2.4                         |
| 2.6 — Decommission Google      | After 2-week soak |                                   |
| 2.7 — Hardening                | Ongoing           | After 2.4                         |
| **Wave 2 total**               | ~3 weeks (incl. soak) |                               |
| **Total elapsed**              | **~6 weeks**      | Family disruption: Wave 2 cutover evening only |

---

### Final Cost Summary (fill in after Wave 2)

| Item                            | Cost        |
| ------------------------------- | ----------- |
| Infomaniak kSuite (actual plan) | €___/mo     |
| Hetzner CX23 VPS                | ~€4/mo      |
| Hetzner BX11 Storage Box        | ~€4/mo      |
| INWX domains (~€76/yr)          | ~€6.30/mo   |
| **Total**                       | **€___/mo** |
| **Previous spend**              | ~€58-81/mo  |
| **Saving**                      | **€___/mo** |
