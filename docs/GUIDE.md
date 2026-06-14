# Haven Deployment Guide

> How to deploy the Haven family platform from zero to running.

This guide walks through the entire deployment process for haven, from setting up accounts and generating secrets to provisioning infrastructure and configuring services. By following these steps, you will have a fully functional self-hosted platform running on a Hetzner infrastructure, with automated backups to a Hetzner Storage Box.

## Overview

**haven** is a self-hosted family platform deployed on Hetzner infrastructure and managed entirely through code.

### Overview Hearth System

The hearth system is the core of haven, running on a Hetzner VPS. It hosts all the main services (Authentik, Vaultwarden, Infisical, Caddy) in a single Docker Compose stack. The hearth system is provisioned with Terraform and configured with Ansible, all orchestrated through GitHub Actions pipelines.

```text
haven (workspace)
├── hearth (VPS — Docker Compose)          ← deployed now
│   ├── Caddy          — reverse proxy + auto-TLS
│   ├── Authentik      — SSO / identity    → auth.huybrechts.xyz
│   ├── Vaultwarden    — passwords         → vault.huybrechts.xyz
│   ├── Infisical      — secrets mgmt      → secrets.huybrechts.xyz
│   ├── Portainer      — container mgmt    → portainer.huybrechts.xyz
│   └── WUD            — update notifier   → wud.huybrechts.xyz
│
├── forge (VPS — k3s)                      ← future
│   └── (workload services TBD)
│
└── storage box (BX11, 1 TB)               ← off-site backups
    └── BorgBackup repo (daily, encrypted)
```

### Overview Forge System

The forge system is a k3s cluster running on dedicated Hetzner VPS. It will host workload services that don't fit the hearth's "core platform" scope, such as self-hosted services as a media servers, home automation controllers, etc.

### Overview Services

| Layer                | Service                          | Provider                     | Notes                                                                                                                                   |
| -------------------- | -------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Email                | kSuite Mail                      | Infomaniak (CH 🇨🇭)            | 5 mailboxes, custom domains, alias domains, forwarding, webmail, CalDAV/CardDAV, ActiveSync. SPF/DKIM/DMARC managed.                    |
| Calendar             | kSuite Calendar                  | Infomaniak (CH 🇨🇭)            | Shared family calendars, delegation, CalDAV, iOS/Android sync.                                                                          |
| Contacts             | kSuite Contacts                  | Infomaniak (CH 🇨🇭)            | CardDAV, vCard import/export, mobile sync.                                                                                              |
| Files                | kDrive                           | Infomaniak (CH 🇨🇭)            | 3–6 TB shared storage, desktop + mobile apps, web access, versioning.                                                                   |
| Docs / Office        | OnlyOffice (via kDrive)          | Infomaniak (CH 🇨🇭)            | Docs/Sheets/Slides in browser; no simultaneous editing required.                                                                        |
| Photos               | Immich                           | Hetzner VPS (DE 🇩🇪)           | Google Photos replacement; timeline, face recognition, shared albums, mobile auto-upload app.                                           |
| Passwords            | Vaultwarden                      | Hetzner VPS (DE 🇩🇪)           | Self-hosted Bitwarden server; family uses existing Bitwarden Firefox extension + iPhone app unchanged.                                  |
| App secrets & config | Infisical                        | Hetzner VPS (DE 🇩🇪)           | Per-app / per-env secrets **and** key-value app config; CLI + SDK for home-grown apps and CI/CD; replaces Azure App Config / Consul KV. |
| Identity (SSO)       | **Authentik** (or Keycloak)      | Hetzner VPS (DE 🇩🇪)           | OIDC/OAuth2 SSO for Immich, Infisical, Vaultwarden and home-grown apps; 2FA enforcement; user lifecycle management.                     |
| Compute / apps       | Docker on Hetzner                | Hetzner VPS (DE 🇩🇪)           | Home-grown apps, Immich, Vaultwarden, Infisical run as Docker Compose services.                                                         |
| Reverse proxy        | Caddy                            | Hetzner VPS (DE 🇩🇪)           | Automatic TLS (Let's Encrypt), subdomain routing for all VPS services.                                                                  |
| Backups              | BorgBackup → Hetzner Storage Box | Hetzner (DE 🇩🇪)               | Encrypted daily backups of VPS data (Vaultwarden, Immich, Infisical, app DBs). kDrive has built-in 30-day versioning.                   |
| DNS                  | **INWX** (or Hetzner DNS)        | INWX (DE 🇩🇪) / Hetzner (DE 🇩🇪) | MX, SPF, DKIM, DMARC, A/CNAME for VPS services per domain. INWX for registration + DNS; delegate to Hetzner DNS if preferred.           |

### Overview Components

| Component     | Technology                                | Where                           |
| ------------- | ----------------------------------------- | ------------------------------- |
| Configuration | strata (YAML → Terraform artifacts)       | This repo (`config/`)           |
| Provisioning  | Terraform / OpenTofu via Hetzner provider | GitHub Actions pipeline         |
| Server setup  | Ansible (init + config + deploy)          | GitHub Actions pipeline         |
| Services      | Docker Compose (10 containers)            | Hearth VPS (`/opt/haven/`)      |
| DNS           | INWX                                      | `huybrechts.xyz` + subdomains   |
| Backups       | BorgBackup → Hetzner Storage Box          | Daily 02:00 UTC, port 23        |
| Secrets       | GitHub Environment Secrets (`production`) | Secrets in pipeline environment |
| State         | Terraform Cloud (remote backend)          | `haven_deploy_prd` workspace    |
| Storage       | Hetzner Storage Box (BX11, 1 TB)          | Off-site backups                |

## Prerequisites

The following accounts, tools, and resources are required to follow this guide and deploy the haven platform. Make sure to set up each of these before proceeding with the deployment steps.

### Required Accounts

You will need accounts for the following services. Create them in the recommended order, since some credentials are needed for later steps.

| Service         | URL                               | Link                          | Notes                                     |
| --------------- | --------------------------------- | ----------------------------- | ----------------------------------------- |
| Bitwarden       | <https://bitwarden.com>           | [click](./bitwarden.md)       | To store the break-the-glass credentials  |
| INWX            | <https://www.inwx.de>             | [click](./inwx.md)            | To manage DNS records                     |
| GitHub          | <https://github.com>              | [click](./github.md)          | To manage source code and CI/CD pipelines |
| Hetzner         | <https://console.hetzner.cloud>   | [click](./hetzner.md)         | To provision and manage VPS instances     |
| Infomaniak      | <https://manager.infomaniak.com>  | [click](./infomaniak.md)      | To manage email and other services        |
| Healthchecks.io | <https://healthchecks.io>         | [click](./healthchecks-io.md) | To monitor service uptime                 |
| UptimeRobot     | <https://uptimerobot.com>         | [click](./uptimerobot.md)     | To monitor service uptime                 |
| Terraform Cloud | <https://app.terraform.io>        | [click](./terraform.md)       | To manage infrastructure as code          |
| Storage Box     | <https://www.hetzner.com/storage> | [click](./hetzner.md)         | To manage off-site backups                |

> **Note** Secure storage of credentials is critical. Use Vaultwarden or another password manager to store all account credentials, API keys, and secrets. Avoid hardcoding sensitive information in code or configuration files. If needed store them temporarily in a secure notes section while setting up, then move to the password manager. From this point forward, we will assume all credentials are stored securely and referenced from there.

### Required Bitwarden Account

1. Create a Bitwarden account if you don't have one.
2. Create a new vault or folder named "Haven" to store all related credentials and secrets.

### Required INWX (Domain Registrar) Account

1. Sign up at <https://www.inwx.de/en>
2. Store the INWX account credentials in Bitwarden.

### Required GitHub Account

1. Create a GitHub account if you don't have one.
2. Store the GitHub account credentials in Bitwarden.
3. Create a new repository named `haven` (or a name of your choice) to host the configuration and code for the haven platform.
4. Configure an Environment named `production` (or a name of your choice) in your repository.
5. Clone the repository to your local machine to start working with it.

### Required Terraform Cloud Account

Strata's Terraform provisioning can use Terraform Cloud as a remote backend for state management. This is optional but recommended for better state handling, collaboration, and visibility. If you choose to use Terraform Cloud, create an account and workspace as follows:

1. Sign up at <https://app.terraform.io/signup>
2. Create organization `huybrechts-xyz`
3. Generate API token: User Settings → Tokens → Create token
4. Store the API token in Bitwarden

> Note: Workspace will be created automatically by the workflow on first run, but you can pre-create it for convenience.

### Required Hetzner Cloud Account

1. Sign up at <https://console.hetzner.cloud>
2. Store the Hetzner account credentials in Bitwarden.
3. Create a project named "Haven" to group all related resources (VMs, firewalls, storage boxes).

### Required Infomaniak Account

1. Sign up at <https://manager.infomaniak.com/en>
2. Store the Infomaniak account credentials in Bitwarden.

### Required Healthchecks.io Account

1. Sign up at <https://healthchecks.io>
2. Store the Healthchecks.io account credentials in Bitwarden.

### Required UptimeRobot Account

1. Sign up at <https://uptimerobot.com>
2. Store the UptimeRobot account credentials in Bitwarden.

### Required Tool Installations

You will need the following tools installed on your workstation to follow this guide and manage the haven platform:

| Tool       | Version | Install                                                                              |
| ---------- | ------- | ------------------------------------------------------------------------------------ |
| `strata`   | ≥ 0.3.0 | `pip install xyz-strata==0.3.0`                                                      |
| OpenTofu   | ≥ 1.6   | `choco install opentofu` or [opentofu.org](https://opentofu.org/docs/intro/install/) |
| Ansible    | ≥ 2.14  | `pip install ansible-core`                                                           |
| GitHub CLI | latest  | `winget install GitHub.cli`                                                          |
| Git        | latest  | `winget install Git.Git`                                                             |

**Verify:**

```powershell
strata --version
tofu --version
ansible --version
gh --version
```

## Domain Registration or Transfer

### Domain Names

The primary domain for haven is `huybrechts.xyz`. This is where the main services will be hosted. Additional domains are reserved for development and personal use.

1. Transfer or register domains at INWX.
2. Verify nameservers are set to INWX defaults (`ns.inwx.net`, `ns2.inwx.net`, `ns3.inwx.eu`).
3. Enable WHOIS privacy on all domains (INWX → Domain → ID Protection).

**Registrar:** INWX (<https://www.inwx.de>)  
**Nameservers:** INWX defaults (`ns.inwx.net`, `ns2.inwx.net`, `ns3.inwx.eu`)

| Domain           | Registrar | Notes           |
| ---------------- | --------- | --------------- |
| `huybrechts.xyz` | INWX      | Primary (haven) |
| `huybrechts.dev` | INWX      | Development     |
| `alderwyn.xyz`   | INWX      | Reserved        |
| `madebyjana.be`  | INWX      | Personal site   |

### Domain Transfer Steps

| #   | Task                               | Notes                                                                                                                                                         |
| --- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Unlock domain at current registrar | This allows the domain to be transferred out.                                                                                                                 |
| 2   | Obtain EPP/Auth code               | This is a unique code required to authorize the transfer. It can usually be found in the domain management section of the current registrar's dashboard.      |
| 3   | Initiate transfer at INWX          | Go to INWX → Domains → Transfer domain → Enter domain name and EPP code → Follow prompts to complete the transfer process.                                    |
| 4   | Approve transfer                   | You may receive an email from the current registrar asking you to approve the transfer. Follow the instructions in the email to approve it.                   |
| 5   | Wait for transfer to complete      | Domain transfers can take anywhere from a few hours to several days to complete. You can check the status in both the current registrar and INWX dashboards.  |
| 6   | Verify transfer and update DNS     | Once the transfer is complete, verify that the domain is now listed in your INWX account. Update the DNS records as needed for haven.                         |
| 7   | Enable WHOIS privacy               | INWX → Domains → ID Protection → Enable for the transferred domain. This will protect your personal information from being publicly visible in WHOIS lookups. |

### Domain Records for Huybrechts.xyz

| Type | Name                             | Priority | Value                                     | TTL  | Notes                                                                                 |
| ---- | -------------------------------- | -------- | ----------------------------------------- | ---- | ------------------------------------------------------------------------------------- |
| A    | `huybrechts.xyz`                 |          | `<server-ip-address>`                     | 3600 | Root domain pointing to the hearth VPS (Caddy reverse proxy)                          |
| A    | `auth.huybrechts.xyz`            |          | `<server-ip-address>`                     | 3600 | Subdomain for Authentik service (SSO)                                                 |
| A    | `vault.huybrechts.xyz`           |          | `<server-ip-address>`                     | 3600 | Subdomain for Vaultwarden service (password manager)                                  |
| A    | `secrets.huybrechts.xyz`         |          | `<server-ip-address>`                     | 3600 | Subdomain for secrets management service                                              |
| A    | `portainer.huybrechts.xyz`       |          | `<server-ip-address>`                     | 3600 | Subdomain for Portainer service (container management)                                |
| A    | `wud.huybrechts.xyz`             |          | `<server-ip-address>`                     | 3600 | Subdomain for WUD service                                                             |
| CAA  | `huybrechts.xyz`                 |          | `128 issue "letsencrypt.org"`             | 3600 | CAA record to allow Let's Encrypt to issue TLS certificates for the domain            |
| MX   | `huybrechts.xyz`                 | 10       | `mail.huybrechts.xyz`                     | 3600 | MX record pointing to the mail server (Infomaniak)                                    |
| TXT  | `huybrechts.xyz`                 |          | `v=spf1 include:mail.infomaniak.ch ~all`  | 3600 | SPF record to authorize Infomaniak mail servers to send email on behalf of the domain |
| TXT  | `mail._domainkey.huybrechts.xyz` |          | `v=DKIM1; k=rsa; p=...` (from Infomaniak) | 3600 | DKIM record for email authentication (value provided by Infomaniak)                   |

Add the MX and TXT records for email once the VPS is provisioned and the IP address is known. The email setup will be covered in the "Configure Email" section of this guide. Settings are described by the [mail server provider](./infomaniak.md) (Infomaniak) and must be added to INWX for proper email delivery.

### Domain DNSSEC — DO NOT ENABLE

> ⚠️ **Never enable DNSSEC at INWX for `huybrechts.xyz`.**
>
> INWX creates DS records at the `.xyz` TLD registry but does NOT automatically install corresponding DNSKEY records in the zone. This creates a broken DNSSEC chain → validating resolvers (Google 8.8.8.8, Cloudflare 1.1.1.1) return `SERVFAIL` → Caddy ACME challenges fail → no TLS certificates.
>
> If accidentally enabled: INWX → Domains → `huybrechts.xyz` → DNSSEC → delete ALL keys. Propagation takes ~1 hour.

## Secrets and Credential Management

Generate all secrets once, store every value in Vaultwarden, then configure them in GitHub and Terraform Cloud.

> Note. Strata can generate random secrets for you during provisioning. So no extra tools are needed. You do need to generate the secrets at least once and store them in Vaultwarden, because they are required as GitHub Secrets for the deployment workflow to run successfully.

```powershell
# Strata
strata secret generate --length 64 --format urlsafe
strata secret generate --length 64 --format hex
```

### Secret for Hetzner SSH Deployment Key

Create an ed25519 SSH key pair for deployment. The public key goes to Hetzner (for Terraform provisioning and BorgBackup), the private key goes to GitHub Secrets (for the deployment workflow) and Bitwarden. You can generate the key pair using PowerShell or any SSH key generation tool. Bitwarden also has a built-in SSH key generator that can create and store the key pair directly in your vault.

```powershell
# Generate ed25519 SSH key pair
ssh-keygen -t ed25519 -C "haven-deploy" -f ~/.ssh/haven_ed25519 -N ""

# Public key → Hetzner Cloud project
Get-Content ~/.ssh/haven_ed25519.pub

# Private key → GitHub Secrets
Get-Content ~/.ssh/haven_ed25519 -Raw
```

### Secrets for Hetzner S3 Object Storage

Hetzner Object Storage uses S3-compatible credentials. Each bucket gets its own access key pair, created in the Hetzner Cloud console under **Object Storage → Access Keys**.

1. [console.hetzner.cloud](https://console.hetzner.cloud) → Project → Object Storage → Access Keys → Create access key
2. Create one key pair per bucket (photos, media, archive)
3. Copy the **Access Key ID** and **Secret Access Key** immediately — the secret is only shown once
4. Store all six values in Bitwarden and GitHub Secrets (see table below)

| GitHub Secret                      | Value               | Notes                                |
| ---------------------------------- | ------------------- | ------------------------------------ |
| `S3_PHOTOS_ACCESS_KEY`             | Access Key ID       | Hetzner Object Storage — photos      |
| `S3_PHOTOS_SECRET_KEY`             | Secret Access Key   | Hetzner Object Storage — photos      |
| `S3_MEDIA_ACCESS_KEY`              | Access Key ID       | Hetzner Object Storage — media       |
| `S3_MEDIA_SECRET_KEY`              | Secret Access Key   | Hetzner Object Storage — media       |
| `S3_ARCHIVE_ACCESS_KEY`            | Access Key ID       | Hetzner Object Storage — archive     |
| `S3_ARCHIVE_SECRET_KEY`            | Secret Access Key   | Hetzner Object Storage — archive     |

> The secret key is only displayed once at creation time. If lost, delete the key and create a new one.

### Secret Keys Summary

Run each command, copy the output, and save it in Vaultwarden under a "Haven Secrets" entry. Use the "Secure Note" type and create fields for each secret (e.g. `AUTHENTIK_SECRET_KEY`, `VAULTWARDEN_ADMIN_TOKEN`, etc.) to keep them organized. You can also add notes about what each secret is for and where it's used.

| Secret                          | Value                            | Notes                                                  |
| ------------------------------- | -------------------------------- | ------------------------------------------------------ |
| `TERRAFORM_API_TOKEN`           | Terraform Cloud API token        | Created by Terraform Cloud user                        |
| `HETZNER_API_TOKEN`             | Hetzner Cloud project token      | Created by Hetzner Cloud user, read/write              |
| `HETZNER_PUBLIC_KEY`            | SSH public key (`.pub`)          | Single line (see Hetzner SSH Deployment Key section)   |
| `HETZNER_PRIVATE_KEY`           | SSH private key (full content)   | Including `-----BEGIN/END-----` lines                  |
| `HETZNER_ROOT_PASSWORD`         | Random password                  | From generate step                                     |
| `AUTHENTIK_SECRET_KEY`          | Random string (86 chars)         | `token_urlsafe(64)`                                    |
| `AUTHENTIK_POSTGRESQL_PASSWORD` | Random password                  | `token_urlsafe(32)`                                    |
| `VAULTWARDEN_ADMIN_TOKEN`       | Argon2 hashed token              | See note below                                         |
| `VAULTWARDEN_SSO_CLIENT_SECRET` | Pre-generated OIDC client secret | `token_urlsafe(48)` — used in Authentik provider setup |
| `WUD_SSO_CLIENT_SECRET`         | Pre-generated OIDC client secret | `token_urlsafe(48)` — used in Authentik provider setup |
| `INFISICAL_AUTH_SECRET`         | 64 hex chars                     | `token_hex(32)`                                        |
| `INFISICAL_ENCRYPTION_KEY`      | **32 chars exactly**             | `token_hex(16)` — not 64!                              |
| `INFISICAL_POSTGRESQL_PASSWORD` | Random password                  | `token_urlsafe(32)`                                    |
| `BORG_PASSPHRASE`               | Random passphrase                | `token_urlsafe(48)`                                    |
| `HETZNER_STORAGEBOX_PASSWORD`   | Storage Box sub-account password | Set when creating sub-account                          |
| `S3_PHOTOS_ACCESS_KEY`          | Hetzner S3 access key ID         | Object Storage — photos bucket                         |
| `S3_PHOTOS_SECRET_KEY`          | Hetzner S3 secret access key     | Object Storage — photos bucket                         |
| `S3_MEDIA_ACCESS_KEY`           | Hetzner S3 access key ID         | Object Storage — media bucket                          |
| `S3_MEDIA_SECRET_KEY`           | Hetzner S3 secret access key     | Object Storage — media bucket                          |
| `S3_ARCHIVE_ACCESS_KEY`         | Hetzner S3 access key ID         | Object Storage — archive bucket                        |
| `S3_ARCHIVE_SECRET_KEY`         | Hetzner S3 secret access key     | Object Storage — archive bucket                        |
| `AUTHENTIK_EMAIL__USERNAME`     | SMTP username                    | From Infomaniak                                        |
| `AUTHENTIK_EMAIL__PASSWORD`     | SMTP password / app password     | From Infomaniak                                        |

> ⚠️ REMARKS
>
> `INFISICAL_ENCRYPTION_KEY` must be **exactly 32 characters**. Using <> 32 chars causes Infisical to crash with "Invalid key length". Use `token_hex(16)` (16 bytes = 32 hex chars).
>
> `VAULTWARDEN_ADMIN_TOKEN` must be stored as an **Argon2 hash**, not plain text. Generate a plain-text token first, then hash it:
> Enter your plain-text token when prompted — copy the $argon2id$... output
>
> ```bash
> docker exec -it haven-vaultwarden-1 /vaultwarden hash --preset owasp
> ```
>
> Store the **plain-text token** in Vaultwarden (you type this to log in to the admin panel).
> Store the **`$argon2id$...` hash** as the `VAULTWARDEN_ADMIN_TOKEN` GitHub Secret.

### Environment Variables

Repo → Settings → Environments → `production` → add these **variables** (not secrets):

| Variable                       | Value                        | Notes                                        |
| ------------------------------ | ---------------------------- | -------------------------------------------- |
| `STORAGEBOX_HOST`              | `u604953.your-storagebox.de` | Storage Box hostname (shared across systems) |
| `STORAGEBOX_SUBACCOUNT_HEARTH` | `u604953-sub1`               | Hearth sub-account username                  |
| `STORAGEBOX_SUBACCOUNT_FORGE`  | `u604953-sub2`               | Forge sub-account username                   |
| `HEALTHCHECK_PING_URL_BACKUP`  | `https://hc-ping.com/<uuid>` | Healthchecks.io ping URL for backup cron     |

> Variables are non-sensitive configuration values that differ per environment. Moving them here (instead of hardcoding in repo files) means the same code can target a different Storage Box by changing only the environment variables.
>
> Secrets must be in the `production` **environment**, not repository-level, or the workflow won't see them.
> This must match the `production` environment referenced in the workflow YAML (`deploy.yml`).

## Infrastructure Setup

Hetzner Cloud is the VPS hosting provider for haven. You will need to create a project, generate an API token, and add the SSH public key for deployment.

### Infrastructure Storage Box

The storage box is where BorgBackup will store encrypted backups of the hearth system. Hetzner Storage Boxes do not have an API, so this step must be done manually through the Hetzner Robot interface.

There is no API or Terraform provider for Hetzner Storage Boxes, so this step must be done manually through the Hetzner Robot interface. Follow these steps to set up the storage box:

1. Sign in at [console.hetzner.com](https://console.hetzner.com) (same Hetzner account)
2. Order a **BX11** Storage Box (1 TB, Nuremberg region)
3. Once activated, go to Storage Box settings → Sub-accounts
4. Create sub-account (e.g. `u604953-sub1`), set a password, enable SSH access
5. Enable **External reachability** on the sub-account (required for port 23 access from VPS public IP)
6. Note the hostname (e.g. `u604953.your-storagebox.de`) and sub-account username
7. Store credentials in Bitwarden and GitHub Secrets (see table above)
8. Add to GitHub Environment Variables (see table below):
   - `STORAGEBOX_HOST` = hostname
   - `STORAGEBOX_SUBACCOUNT` = sub-account username

> **⚠️ Hetzner Storage Boxes have no API or Terraform provider. This step is entirely manual and cannot be automated.**
> **⚠️ External reachability must be enabled** — without it, only Hetzner-internal traffic can reach port 23. The VPS connects via its public IP, so BorgBackup will time out if this is off.

### Infrastructure VPS hosting

The Haven system runs on a set of VPS instances hosted on Hetzner Cloud. The main instance is the "hearth" VPS, which runs the core services in a Docker Compose stack. The "forge" VPS will be used for additional services and workloads in the future. Follow these steps to set up the infrastructure hosting:

1. [console.hetzner.com](https://console.hetzner.com) → Projects → Create project "Haven"
2. Go to Security → SSH Keys → Add SSH key → Paste the content of `~/.ssh/haven_ed25519.pub`
3. Go to Security → API Tokens → Create token → Name: "Haven Deploy" → Permissions: Read/Write
4. Store credentials in Bitwarden and GitHub Secrets (see table above) as `HETZNER_API_TOKEN`

The VPS provisioning and configuration will be handled by the GitHub Actions workflows defined in this repository, so there is no need to manually create VPS instances or configure them at this stage. The `deploy.yml` workflow will take care of provisioning the VPS, configuring it with Ansible, and deploying the Docker Compose stack.

### Infrastructure Workflow

#### Configuration by Strata

The configuration for haven is defined in the `config/` directory using Strata's Kubernetes-style schema. Strata reads these YAML files and generates the Terraform artifacts consumed by the deployment workflow.

#### Provisioning by the deploy pipeline

Infrastructure provisioning is handled by the `deploy.yml` GitHub Actions workflow. The pipeline uses the Hetzner API and the deployment SSH key to provision the VPS, apply Terraform changes, and run the Ansible playbooks required to configure the target system.

#### Hearth deployment

The hearth system is deployed by the same `deploy.yml` workflow and runs as a Docker Compose stack on the Hetzner VPS. It hosts the core platform services such as Caddy, Authentik, Vaultwarden, Infisical, Portainer, and WUD.

#### Forge deployment

The forge system is planned as a separate workload platform. It will run on its own infrastructure and be deployed with Helm charts managed through Argo CD on a k3s cluster.

### Infrastructure Provisioning

When we first run the deployment workflow, it will provision the infrastructure defined in the Strata configuration. This includes creating the VPS instance for the hearth system, setting up the firewall rules, and configuring the network settings.

GitHub Actions → `Deploy - haven` → Run workflow. This runs `strata build` + Terraform to provision the VPS, firewall, and network. Ansible playbooks are skipped on this first run.

| Input        | Value           |
| ------------ | --------------- |
| `branch`     | `<branch-name>` |
| `run_init`   | `false`         |
| `run_config` | `false`         |
| `run_deploy` | `false`         |

> Note the **server IP** from the Terraform output — you need it for the DNS A records above.

### Infrastructure DNS Records

Once you have the server IP, add the A records listed in [Domain Records for Huybrechts.xyz](#domain-records-for-huybrechtsxyz) at INWX.

## Initiale Setup

Bootstrap the server with Docker, the `haven` service user, directory structure, and SSH hardening.

**Playbook:** `deploy/ansible-init/hearth-init.yml`  
**Runs once** on a fresh server. Safe to re-run — all tasks are idempotent.

### Initializing Tasks

| Task                    | Details                                                               |
| ----------------------- | --------------------------------------------------------------------- |
| Set timezone            | `Europe/Brussels`                                                     |
| Install packages        | `curl`, `ca-certificates`, `gnupg`, `ufw`, `fail2ban`                 |
| Install Docker          | Official Docker CE repository, pinned version                         |
| Create `haven` user     | System user, home `/opt/haven`, member of `docker` group              |
| Create directory tree   | `/opt/haven/etc`, `/opt/haven/var/data`, `/opt/haven/var/certs`, etc. |
| Generate BorgBackup key | `borg_ed25519` SSH key pair in `/opt/haven/.ssh/`                     |
| SSH hardening           | `PermitRootLogin no`, `PasswordAuthentication no`, key-only auth      |

### Initializing Directory for Hearth Services

```ascii
/opt/haven/
├── etc/                    ← Config files (compose, Caddyfile, .env)
│   ├── caddy/
│   │   └── config/
│   └── authentik/
│       └── templates/      ← Owned by uid 1000 (authentik container user)
├── scripts/                ← Backup script (deployed by hearth-config)
└── var/
    ├── certs/              ← Caddy TLS certificates (root:root 0777)
    └── data/
        ├── authentik/
        │   ├── postgresql/ ← root-owned, postgres container initializes
        │   └── media/      ← Owned by uid 1000 (authentik container user)
        │       └── public/
        ├── infisical/      ← root-owned parent, postgres container initializes
        └── vaultwarden/
```

### Initalizing Workflow

In the next run of the deployment workflow, we will execute the `hearth-init.yml` Ansible playbook to perform the initialization tasks on the newly provisioned VPS. This sets up the necessary environment for the hearth services to run properly.

GitHub Actions → `Deploy - haven` → Run workflow with the following inputs:

| Input            | Value           |
| ---------------- | --------------- |
| `branch`         | `<branch-name>` |
| `run_init`       | `true`          |
| `configure_borg` | `false`         |
| `run_config`     | `false`         |
| `run_deploy`     | `false`         |

After the run completes, check the workflow log for the task **"Display borg SSH public key"** — you'll need this key later for BorgBackup setup. Store this public key in Bitwarden.

> **Note:** After init completes, SSH root login is disabled. All subsequent access is via the deploy key through the pipeline.

### Initializing Backup Configuration

BorgBackup backs up critical data to the Hetzner Storage Box with `repokey-blake2` encryption, daily at 02:00 UTC.

- **Target:** `<STORAGEBOX_SUBACCOUNT>@<STORAGEBOX_HOST>:./hearth` (SSH port 23)
- **Data:** Authentik, Vaultwarden, Infisical volumes + `/opt/haven/etc`
- **Retention:** 7 daily, 4 weekly, 6 monthly
- **Log:** `/var/log/haven-backup.log`

Add the `HETZNER_STORAGEBOX_PASSWORD` secret (the sub-account password from Hetzner Robot) to GitHub Environment Secrets. Should already be in Bitwarden from the secrets generation step.

GitHub Actions → `Deploy - haven` → Run workflow with the following inputs:

| Input            | Value           |
| ---------------- | --------------- |
| `branch`         | `<branch-name>` |
| `run_init`       | `true`          |
| `configure_borg` | `true`          |
| `run_config`     | `false`         |
| `run_deploy`     | `false`         |

The pipeline will automatically:

1. Generate an ed25519 SSH key pair on the VPS (`/opt/haven/.ssh/borg_ed25519`)
2. Upload the public key to the Storage Box using Hetzner's `install-ssh-key` command (requires `STORAGEBOX_PASSWORD`)
3. Scan the Storage Box host key and add it to `known_hosts`
4. Initialise the BorgBackup repository with `repokey-blake2` encryption
5. Export and display the repository key

> **How SSH key upload works:** Hetzner Storage Boxes require SSH keys to be uploaded via the `install-ssh-key` SSH command — the Robot web UI does not support this for port 23 access. The pipeline automates this using `sshpass` with the sub-account password. See [Hetzner docs: Add SSH keys](https://docs.hetzner.com/storage/storage-box/backup-space-ssh-keys/) for details.

In the workflow log → task **"Show BorgBackup repokey"** → copy the key block and save to Vaultwarden as **"Haven BorgBackup repo key"**.

> ⚠️ Without this key + the passphrase, backups **cannot** be restored.
>
> The repokey is also displayed on every `run_config` run (when `configure_borg: true`), so you can retrieve it later without re-running init.

## Configure Setup

Enforce system configuration on every deploy. Corrects drift without re-installing software.

**Playbook:** `deploy/ansible-config/hearth-config.yml`  
**Runs on every deploy.** Safe to re-run — all tasks are idempotent.

### Configuration Tasks

| Task                       | Details                                                                        |
| -------------------------- | ------------------------------------------------------------------------------ |
| Stop competing web servers | Disables `apache2` and `nginx` if present (frees ports 80/443)                 |
| Security updates           | `apt upgrade safe`, removes unused packages                                    |
| Install packages           | `borgbackup`, `htop`, `ncdu`, `fail2ban`, `jq`, `unattended-upgrades`          |
| Timezone                   | Enforces `Europe/Brussels`                                                     |
| Unattended upgrades        | Security-only, no auto-reboot                                                  |
| Docker                     | Ensures Docker service is running and enabled                                  |
| Haven user                 | Ensures `haven` user/group, `docker` group membership                          |
| Directory structure        | Enforces ownership and permissions on `/opt/haven/` tree                       |
| fail2ban                   | Ensures running and enabled                                                    |
| SSH hardening              | Password auth disabled, root key-only (`prohibit-password`)                    |
| BorgBackup (conditional)   | Deploys backup script, passphrase file, cron job (when `configure_borg: true`) |

### Configuration Workflow

GitHub Actions → `Deploy - haven` → Run workflow:

| Input            | Value           |
| ---------------- | --------------- |
| `branch`         | `<branch-name>` |
| `run_init`       | `true`          |
| `configure_borg` | `true`          |
| `run_config`     | `false`         |
| `run_deploy`     | `false`         |

> On first deploy, run config to set up the system.
> The backup script and daily cron job are now active.

### Configuration Monitoring with Healthchecks.io

Healthchecks.io monitors **cron job execution** — it alerts when a scheduled task (like BorgBackup) fails to check in on time.

1. Create a project named `haven`
2. Create checks (see below table) with a 25-hour timeout (24h period + 1h grace)
3. Copy the ping URL (e.g. `https://hc-ping.com/<uuid>`)
4. Add it as GitHub Environment Variable `HEALTHCHECK_PING_URL_BACKUP`
5. Run pipeline with `branch: <branch-name>`, `run_config: true`, `run_deploy: false` to deploy the updated backup script
6. Configure alert integrations (email, Telegram, or Pushover)
7. Store credentials in Vaultwarden

| Check name      | Period   | Grace  | Purpose                           |
| --------------- | -------- | ------ | --------------------------------- |
| `hearth-backup` | 24 hours | 1 hour | BorgBackup daily cron (02:00 UTC) |

> Healthchecks.io is for **dead man's switch** monitoring — it alerts on *absence* of activity. If the backup cron doesn't ping within 25 hours, you get an alert.

## Deployment Setup

Once configuration is enforced, we can deploy the hearth services in a Docker Compose stack. The deployment playbook ensures the latest configuration is applied, pulls the latest images, and restarts containers as needed.

### Deploy Hearth

The hearth system runs the core services (Caddy, Authentik, Vaultwarden, Infisical, Portainer, WUD) in a Docker Compose stack. The deployment workflow ensures the latest configuration is applied and the containers are up to date.

Deploy the Docker Compose stack with all 9 containers to the server.

**Playbook:** `deploy/ansible-deploy/hearth-deploy.yml`  
**Runs on every deploy.** Safe to re-run — pulls latest images and recreates changed containers.

| Task                       | Details                                                            |
| -------------------------- | ------------------------------------------------------------------ |
| Create service directories | Config dirs, data dirs, correct ownership (uid 1000 for Authentik) |
| Sync build artifacts       | Copies `docker-compose.yml` and `Caddyfile` to `/opt/haven/etc/`   |
| Write `.env` file          | Injects service secrets (never committed to repo, `mode 0600`)     |
| Clean up old stacks        | Stops any lingering compose projects, releases ports 80/443        |
| Pull images                | `docker compose pull` — fetches latest images for all 9 services   |
| Start services             | `docker compose up -d --remove-orphans` (project name: `haven`)    |
| Restart Authentik          | Ensures server + worker pick up correct `/media` ownership         |
| Restart Caddy              | Only when Caddyfile changed or no valid Let's Encrypt certs found  |
| Diagnostics                | Waits 60s, then displays all container states + logs for debugging |

**Deploy Hearth services:**

| Container                  | Service              | Port           |
| -------------------------- | -------------------- | -------------- |
| `haven-caddy-1`            | Caddy reverse proxy  | 80, 443        |
| `haven-authentik-server-1` | Authentik server     | (behind Caddy) |
| `haven-authentik-worker-1` | Authentik worker     | —              |
| `haven-authentik-redis-1`  | Authentik Redis      | —              |
| `haven-authentik-db-1`     | Authentik PostgreSQL | —              |
| `haven-vaultwarden-1`      | Vaultwarden          | (behind Caddy) |
| `haven-infisical-1`        | Infisical backend    | (behind Caddy) |
| `haven-infisical-redis-1`  | Infisical Redis      | —              |
| `haven-infisical-db-1`     | Infisical PostgreSQL | —              |

**Run hearth-deploy:**

GitHub Actions → `Deploy - haven` → Run workflow:

| Input            | Value           |
| ---------------- | --------------- |
| `branch`         | `<branch-name>` |
| `run_init`       | `false`         |
| `configure_borg` | `false`         |
| `run_config`     | `true`          |
| `run_deploy`     | `true`          |

> Always run config before deploy — it ensures system packages, Docker, and directory permissions are correct before the compose stack starts.

Caddy obtains Let's Encrypt certificates automatically on first start (~30 seconds). The playbook waits 60 seconds then displays container states for verification.

**Verify services, all must show a login page:**

- `https://auth.huybrechts.xyz` — Authentik
- `https://vault.huybrechts.xyz` — Vaultwarden
- `https://secrets.huybrechts.xyz` — Infisical
- `https://portainer.huybrechts.xyz` — Portainer
- `https://wud.huybrechts.xyz` — WUD (What's Up Docker)

## Service Setup for Hearth

### Setup Caddy

Caddy is the reverse proxy for haven. It runs as a Docker Compose service and automatically obtains TLS certificates from Let's Encrypt. The deployment workflow ensures Caddy is properly configured and running.

The setup of Caddy is mostly automated through the deployment workflow, but you can customize the `Caddyfile` in the `config/` directory to add additional routes, middleware, or services as needed.

### Setup Authentik

Authentik is the SSO provider for haven. It runs as a Docker Compose service and is configured to use PostgreSQL and Redis for storage. The deployment workflow ensures Authentik is properly set up and running.

See the [AUTHENTIK.md](./authentik.md) guide for detailed setup instructions, including creating the admin account, configuring email, and setting up OIDC providers for Vaultwarden and Infisical.

> **Note:** Authentik must be set up before Vaultwarden and Infisical, since they rely on Authentik for authentication.

### Setup Vaultwarden

Vaultwarden is a password manager. After Authentik is set up, you can create the first admin account in Vaultwarden and log in to the web vault.

See the [VAULTWARDEN.md](./bitwarden.md) guide for detailed setup instructions, including creating the admin account, configuring email, and setting up OIDC authentication with Authentik.

> ⚠️ **Admin token:** The `VAULTWARDEN_ADMIN_TOKEN` GitHub Secret must be the Argon2 hash, not the plain-text token. You always log in with the **plain-text** token — Vaultwarden verifies it against the hash internally. If the secret is plain text, Vaultwarden logs a warning on every startup.

### Setup Infisical

Infisical is a secrets management platform used by admins to manage application secrets.

See the [INFISICAL.md](./infisical.md) guide for detailed setup instructions, including creating the admin account, configuring email, and setting up OIDC authentication with Authentik.

### Setup Portainer

Portainer is a container management platform that provides a web UI for managing Docker containers, images, and volumes. It runs as a Docker Compose service and is configured to use the Docker socket for direct access to the Docker API.

See the [PORTAINER.md](./portainer.md) guide for detailed setup instructions, including creating the admin account and configuring authentication with Authentik.

### Setup WUD (What's Up Docker)

WUD is a monitoring dashboard for Docker containers. It provides real-time insights into container performance, resource usage, and logs. It runs as a Docker Compose service and is configured to use the Docker socket for direct access to the Docker API.

See the [WUD.md](./wud.md) guide for detailed setup instructions, including creating the admin account and configuring authentication with Authentik.

### Setup Healthchecks.io

Healthchecks.io is a service for monitoring the uptime of your services. It allows you to create checks for your services and receive notifications if they go down.

See the [HEALTHCHECKS-IO.md](./healthchecks-io.md) guide for detailed setup instructions, including creating checks for the backup cron job and configuring alert integrations.

### Setup BorgBackup

BorgBackup is the backup solution for haven. It runs as a cron job on the hearth VPS and backs up critical data to the Hetzner Storage Box with `repokey-blake2` encryption.

See the [BORGBACKUP.md](./borgbackup.md) guide for detailed setup instructions, including how to restore from backup using the Borg CLI.

### Setup UptimeRobot

UptimeRobot is a service for monitoring the uptime of your services. It allows you to create monitors for your services and receive notifications if they go down.

See the [UPTIMEROBOT.md](./uptimerobot.md) guide for detailed setup instructions, including creating monitors for the Authentik, Vaultwarden, and Infisical web interfaces.

## Infomaniak

Infomaniak is the worksuite for Haven, including email hosting, calendar, and file storage.

See the [INFOMANIAK.md](./infomaniak.md) guide for detailed setup instructions, including creating the email account, generating app passwords, and configuring SMTP settings in Authentik.
