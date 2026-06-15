# Haven Deployment Guide

> How to deploy the Haven family platform from zero to running.

This guide walks through the entire deployment process for haven, from setting up accounts and generating secrets to provisioning infrastructure and configuring services. By following these steps, you will have a fully functional self-hosted platform running on a Hetzner infrastructure, with automated backups to a Hetzner Storage Box.

## Overview

**haven** is a self-hosted family platform deployed on Hetzner infrastructure with Swiss-based file services (Infomaniak kSuite). The system is managed entirely through code (IaC) via strata + Terraform + Ansible.

For system architecture, component inventory, and design rationale, see:

- **[architecture.md](architecture.md)** — System topology, infrastructure specifications, data durability model
- **[design.md](design.md)** — Design decisions, domain/email layout, security posture, monthly costs

### Quick System Overview

Haven consists of **two independent VPS nodes** (Hearth + Forge) plus off-site backups and Swiss-based file services:

```text
haven (workspace)
├── hearth (CX23 — Docker Compose)               ← Core: Authentik, Vaultwarden, Infisical, Caddy
│   └── Services: Auth, Passwords, Secrets, Reverse Proxy
│
├── forge (CPX41 — k3s)                          ← Workload: Immich, Jellyfin, Gatus, apps
│   └── Services: Photos, Media Streaming, Health Dashboard, Home-grown Apps
│
├── storage box (BX11, 1 TB)                     ← Tier 1 Backups: BorgBackup (encrypted)
│   └── NFS mount for Jellyfin media library
│
├── object storage (S3, eu-central, 4 buckets)   ← Immich originals, media overflow, archives
│   └── haven-{photos, media, archive, docs}
│
└── Infomaniak kSuite (Switzerland)              ← Email, Calendar, Contacts, Files, Docs
    └── Tier 2 backups: daily rclone sync to kDrive
```

### Deployment Workflow

Haven uses **three independent GitHub Actions workflows** for independent scheduling and rapid iteration:

| Workflow            | Purpose                                      | Frequency   | When to run                  |
| ------------------- | -------------------------------------------- | ----------- | ---------------------------- |
| `deploy-infra.yml`  | Terraform + S3 provisioning                  | Once (rare) | After infrastructure changes |
| `deploy-hearth.yml` | Core VPS init/config/deploy (Docker Compose) | On-demand   | After service config changes |
| `deploy-forge.yml`  | Workload VPS init/config/deploy (k3s)        | On-demand   | After app/chart updates      |

**Typical deployment order:**
1. Run `deploy-infra.yml` once (Terraform + S3 buckets)
2. Configure DNS at INWX
3. Run `deploy-hearth.yml` for core services
4. Run `deploy-forge.yml` for workload apps

### Service Overview

For detailed component inventory, see [architecture.md](architecture.md#component-inventory).

## Prerequisites

The following accounts, tools, and resources are required to follow this guide and deploy the haven platform. Make sure to set up each of these before proceeding with the deployment steps.

### Required Accounts

> **ACTION:** Create accounts for each of these services, then store the credentials securely in Bitwarden. For each service, follow the linked guide for detailed setup instructions.

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

See [bitwarden.md](./bitwarden.md#initial-setup) for detailed instructions on setting up your Bitwarden account and organizing your vault for the haven platform. In summary:

1. Create a Bitwarden account if you don't have one.
2. Create a new vault or folder named "Haven" to store all related credentials and secrets.

### Required INWX (Domain Registrar) Account

See [inwx.md](./inwx.md#initial-setup) for detailed instructions on setting up your INWX account and configuring DNS for the haven platform. In summary:

1. Sign up at <https://www.inwx.de/en>
2. Store the INWX account credentials in Bitwarden.

### Required GitHub Account

See [github.md](./github.md#initial-setup) for detailed instructions on setting up your GitHub account and repository for the haven platform. In summary:

1. Create a GitHub account if you don't have one.
2. Store the GitHub account credentials in Bitwarden.
3. Create a new repository named `haven` (or a name of your choice) to host the configuration and code for the haven platform.
4. Configure an Environment named `production` (or a name of your choice) in your repository.
5. Clone the repository to your local machine to start working with it.

### Required Terraform Cloud Account

Strata's [Terraform](./terraform#initial-setup) provisioning can use Terraform Cloud as a remote backend for state management. This is optional but recommended for better state handling, collaboration, and visibility. If you choose to use Terraform Cloud, create an account and workspace as follows:

1. Sign up at <https://app.terraform.io/signup>
2. Create organization (e.g., `{org-name}`)
3. Generate API token: User Settings → Tokens → Create token
4. Store the API token in Bitwarden

> Note: Workspace will be created automatically by the workflow on first run, but you can pre-create it for convenience.

### Required Hetzner Cloud Account

See [hetzner.md](./hetzner.md#initial-setup) for detailed instructions on setting up your Hetzner Cloud account and provisioning infrastructure for the haven platform. In summary:

1. Sign up at <https://console.hetzner.cloud>
2. Store the Hetzner account credentials in Bitwarden.
3. Create a project named "Haven" to group all related resources (VMs, firewalls, storage boxes).

### Required Infomaniak Account

See [infomaniak.md](./infomaniak.md#initial-setup) for detailed instructions on setting up your Infomaniak account and configuring email and file services for the haven platform. In summary:

1. Sign up at <https://manager.infomaniak.com/en> for a **kSuite plan** with Mail, Files, and Drive services.
2. Store the Infomaniak account credentials in Bitwarden.

### Required Healthchecks.io Account

See [healthchecks-io.md](./healthchecks-io.md#initial-setup) for detailed instructions on setting up your Healthchecks.io account and configuring uptime monitoring for the haven platform. In summary:

1. Sign up at <https://healthchecks.io>
2. Store the Healthchecks.io account credentials in Bitwarden.

### Required UptimeRobot Account

See [uptimerobot.md](./uptimerobot.md#initial-setup) for detailed instructions on setting up your UptimeRobot account and configuring uptime monitoring for the haven platform. In summary:

1. Sign up at <https://uptimerobot.com>
2. Store the UptimeRobot account credentials in Bitwarden.

### Required Tool Installations

You will need the following tools installed on your workstation to follow this guide and manage the haven platform:

| Tool       | Version | Install                                                                              |
| ---------- | ------- | ------------------------------------------------------------------------------------ |
| `strata`   | ≥ 1.0.0 | `pip install xyz-strata==1.0.0`                                                      |
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

> **ACTION:** Register or transfer your domains to INWX, then configure the DNS records as described in the next section. Before doing this, decide on your primary domain and subdomain structure.

Register or transfer your domain(s) to **INWX** (or your preferred INWX-compatible registrar). Haven is designed to work with domains managed at INWX for DNS automation.

For detailed instructions on registering or transferring domains at INWX, see **[inwx.md](./inwx.md#domain-registration-or-transfer)**.

Before registering or transferring domains, decide on:

1. **Primary domain:** The main domain where Caddy will host your services (auth, vaults, etc.). Choose a domain you're comfortable with long-term.
2. **Subdomains:** You'll need one subdomain per service (e.g., `auth.{domain}`, `vault.{domain}`). Caddy's auto-TLS covers all subdomains with wildcard certificates.
3. **Domain configuration:** See **[domains.md](./domains.md)** for a concrete example with specific domains, subdomains, and DNS records.

## Secrets and Credential Management

Generate all secrets once, store every value in Vaultwarden, then configure them in GitHub and Terraform Cloud.

### Generate Secrets

> Note. Strata can generate random secrets for you during provisioning. So no extra tools are needed. 
> You do need to generate the secrets at least once and store them in Bitwarden, 
> because they are required as GitHub Secrets for the deployment workflow to run successfully.

**Generate random secrets using Python's `secrets` module:**

```powershell
# Using Python's secrets module (available in all Python installations)
python -c "from secrets import token_urlsafe, token_hex; print('urlsafe(64):', token_urlsafe(64)); print('hex(32):', token_hex(32))"

# Or use Strata if available
strata secret generate --length 64 --format urlsafe
strata secret generate --length 64 --format hex
```

### Secret for Hetzner SSH Deployment Key

> **ACTION:** Generate an ed25519 SSH key pair. Store the public key in the Hetzner Cloud project and the private key in GitHub Secrets and Bitwarden.

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

> **ACTION:** Generate an S3 access key pair in the Hetzner Cloud console. Store the Access Key ID and Secret Access Key in Bitwarden and GitHub Secrets.

Hetzner Object Storage uses S3-compatible credentials at the **project level** — one key pair grants access to all buckets in the project. There are no per-bucket IAM policies or scoped keys.

Four buckets are provisioned by the `ansible-s3/forge-s3.yml` playbook:
- `haven-photos` — Immich external photo library
- `haven-media` — media overflow (large binary assets)
- `haven-archive` — cold storage, documents, exports
- `haven-docs` — documentation and operational exports

1. [console.hetzner.cloud](https://console.hetzner.cloud) → Project → Object Storage → Access Keys → Create access key
2. Create **one** key pair (used by the CI/CD pipeline to provision buckets and by apps to read/write them)
3. Copy the **Access Key ID** and **Secret Access Key** immediately — the secret is only shown once
4. Store both values in Bitwarden and GitHub Secrets (see table below)

| GitHub Secret           | Value             | Notes                                                |
| ----------------------- | ----------------- | ---------------------------------------------------- |
| `HETZNER_S3_ACCESS_KEY` | Access Key ID     | Hetzner Object Storage — project-level (all buckets) |
| `HETZNER_S3_SECRET_KEY` | Secret Access Key | Hetzner Object Storage — project-level (all buckets) |

> The secret key is only displayed once at creation time. If lost, delete the key and create a new one.
> Additional key pairs can be created (e.g. a separate pair for rclone offsite sync) but each still has project-wide access — Hetzner does not support bucket-scoped keys.

### Secret Keys Summary

> **ACTION:** Generate all secrets using the commands above, then store them in Bitwarden under a "Haven Secrets" entry. Create fields for each secret and add notes about their purpose.

Run each command, copy the output, and save it in Bitwarden under a "Haven Secrets" entry. Use the "Secure Note" type and create fields for each secret (e.g. `AUTHENTIK_SECRET_KEY`, `VAULTWARDEN_ADMIN_TOKEN`, etc.) to keep them organized. You can also add notes about what each secret is for and where it's used.

| Secret                          | Value                            | Notes                                                                                                    |
| ------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `TERRAFORM_API_TOKEN`           | Terraform Cloud API token        | Created by Terraform Cloud user                                                                          |
| `HETZNER_API_TOKEN`             | Hetzner Cloud project token      | Created by Hetzner Cloud user, read/write                                                                |
| `HETZNER_PUBLIC_KEY`            | SSH public key (`.pub`)          | Single line (see Hetzner SSH Deployment Key section)                                                     |
| `HETZNER_PRIVATE_KEY`           | SSH private key (full content)   | Including `-----BEGIN/END-----` lines                                                                    |
| `HETZNER_ROOT_PASSWORD`         | Random password                  | From generate step                                                                                       |
| `AUTHENTIK_SECRET_KEY`          | Random string (86 chars)         | `token_urlsafe(64)`                                                                                      |
| `AUTHENTIK_POSTGRESQL_PASSWORD` | Random password                  | `token_urlsafe(32)`                                                                                      |
| `VAULTWARDEN_ADMIN_TOKEN`       | Argon2 hashed token              | See note below                                                                                           |
| `VAULTWARDEN_SSO_CLIENT_SECRET` | Pre-generated OIDC client secret | `token_urlsafe(48)` — used in Authentik provider setup                                                   |
| `WUD_SSO_CLIENT_SECRET`         | Pre-generated OIDC client secret | `token_urlsafe(48)` — used in Authentik provider setup                                                   |
| `INFISICAL_AUTH_SECRET`         | 64 hex chars                     | `token_hex(32)`                                                                                          |
| `INFISICAL_ENCRYPTION_KEY`      | **32 chars exactly**             | `token_hex(16)` — not 64!                                                                                |
| `INFISICAL_POSTGRESQL_PASSWORD` | Random password                  | `token_urlsafe(32)`                                                                                      |
| `BORG_PASSPHRASE`               | Random passphrase                | `token_urlsafe(48)`                                                                                      |
| `HETZNER_STORAGEBOX_PASSWORD`   | Storage Box sub-account password | Set when creating sub-account                                                                            |
| `HETZNER_S3_ACCESS_KEY`         | Hetzner S3 access key ID         | Object Storage — project-level, all buckets (photos/media/archive/docs)                                  |
| `HETZNER_S3_SECRET_KEY`         | Hetzner S3 secret access key     | Object Storage — project-level, all buckets (photos/media/archive/docs)                                  |
| `AUTHENTIK_EMAIL__USERNAME`     | SMTP username (kSuite email)     | See [infomaniak.md → SMTP Server Configuration](./infomaniak.md#smtp-server-configuration-for-authentik) |
| `AUTHENTIK_EMAIL__PASSWORD`     | SMTP app password                | See [infomaniak.md → SMTP Server Configuration](./infomaniak.md#smtp-server-configuration-for-authentik) |

> ⚠️ REMARKS
>
> `INFISICAL_ENCRYPTION_KEY` must be **exactly 32 characters**. Using <> 32 chars causes Infisical to crash with "Invalid key length". Use `token_hex(16)` (16 bytes = 32 hex chars).
>
> `VAULTWARDEN_ADMIN_TOKEN` must be stored as an **Argon2 hash**, not plain text. Generate a plain-text token first, then hash it:
>
> 1. Generate a plain-text token: `python -c "from secrets import token_urlsafe; print(token_urlsafe(48))"`
> 2. Hash the token (run after Hearth is deployed and Vaultwarden container is running):
>
>    ```bash
>    # Find the Vaultwarden container name
>    docker ps | grep vaultwarden
>    
>    # Hash the token (replace TOKEN with your plain-text token)
>    docker exec -it <container-name> /vaultwarden hash --preset owasp
>    # Paste your TOKEN when prompted
>    ```
>
> 3. Store the **plain-text token** in Vaultwarden (you type this to log in to the admin panel)
> 4. Store the **`$argon2id$...` hash** as the `VAULTWARDEN_ADMIN_TOKEN` GitHub Secret

### Environment Variables

> **ACTION:** Add the following environment variables to your GitHub repository's `production` environment.

Repo → Settings → Environments → `production` → add these **variables** (not secrets). These are non-sensitive values that the deployment workflow needs to access. They should match the actual values for your Hetzner Storage Box and Healthchecks.io configuration.

| Variable                       | Value                                     | Notes                                                                                               |
| ------------------------------ | ----------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `STORAGEBOX_HOST`              | `{your-storagebox-id}.your-storagebox.de` | Storage Box hostname (find in [Hetzner Robot](https://robot.hetzner.com) → Storage → Storage Boxes) |
| `STORAGEBOX_SUBACCOUNT_HEARTH` | `{storagebox-id}-hearth`                  | Hearth sub-account username (created via Hetzner Robot)                                             |
| `STORAGEBOX_SUBACCOUNT_FORGE`  | `{storagebox-id}-forge`                   | Forge sub-account username (created via Hetzner Robot)                                              |
| `HEALTHCHECK_PING_URL_BACKUP`  | `https://hc-ping.com/{uuid}`              | Healthchecks.io ping URL for backup cron (get from Healthchecks.io dashboard)                       |

**Example values** (for huybrechts.xyz deployment):
- `STORAGEBOX_HOST` → `u604953.your-storagebox.de`
- `STORAGEBOX_SUBACCOUNT_HEARTH` → `u604953-hearth`
- `STORAGEBOX_SUBACCOUNT_FORGE` → `u604953-forge`
- `HEALTHCHECK_PING_URL_BACKUP` → `https://hc-ping.com/550e8400-e29b-41d4-a716-446655440000`

> Variables are non-sensitive configuration values that differ per environment. Moving them here (instead of hardcoding in repo files) means the same code can target a different Storage Box or monitoring setup by changing only the environment variables.
>
> Secrets must be in the `production` **environment**, not repository-level, or the workflow won't see them.
> This must match the `production` environment referenced in the workflow YAML.

## Infrastructure Setup

Hetzner Cloud is the VPS hosting provider for haven. You will need to create a project, generate an API token, and add the SSH public key for deployment.

### Infrastructure Storage Box

> **ACTION:** Set up a Hetzner Storage Box for off-site backups. Create sub-accounts for the hearth and forge systems, enable external reachability, and store the credentials in Bitwarden and GitHub Secrets.

The storage box is where BorgBackup will store encrypted backups of the hearth system. Hetzner Storage Boxes do not have an API, so this step must be done manually through the Hetzner Robot interface.

Follow these steps to set up the storage box:

1. Sign in at [robot.hetzner.com](https://robot.hetzner.com) (same Hetzner account)
2. Order a **BX11** Storage Box (1 TB, Nuremberg region)
3. Once activated, go to Storage Box settings → Sub-accounts
4. Create sub-account (e.g. `u604953-sub1`), set a password, enable SSH access
5. Enable **External reachability** on the sub-account (required for port 23 access from VPS public IP)
6. Note the hostname (e.g. `u604953.your-storagebox.de`) and sub-account username
7. Store credentials in Bitwarden and GitHub Secrets (see table above)
8. Add to GitHub Environment Variables (see [Environment Variables](#environment-variables)):
   - `STORAGEBOX_HOST` = hostname
   - `STORAGEBOX_SUBACCOUNT_HEARTH` = hearth sub-account username
   - `STORAGEBOX_SUBACCOUNT_FORGE` = forge sub-account username

> **⚠️ Hetzner Storage Boxes have no API or Terraform provider. This step is entirely manual and cannot be automated.**
> **⚠️ External reachability must be enabled** — without it, only Hetzner-internal traffic can reach port 23. The VPS connects via its public IP, so BorgBackup will time out if this is off.

### Infrastructure Connectivity

> **ACTION:** Set up the Hetzner Cloud project for haven. Add the SSH public key for deployment and generate an API token for Terraform provisioning.

The Haven system runs on a set of VPS instances hosted on Hetzner Cloud. The main instance is the "hearth" VPS, which runs the core services in a Docker Compose stack. The "forge" VPS is used for additional services and workloads. Follow these steps to set up the infrastructure hosting (assumes the Hetzner project is already created — see [Prerequisites → Hetzner](#required-hetzner-cloud-account)):

1. Go to Security → SSH Keys → Add SSH key → Paste the content of `~/.ssh/haven_ed25519.pub` (Public key from the Hetzner SSH Deployment Key section above)
   > This key is registered at **project level** — Terraform will inject it into every VPS it creates (Hearth, Forge, any future nodes). One key pair covers all servers.
2. Go to Security → API Tokens → Create token → Name: "Haven Deploy" → Permissions: Read/Write
3. Store credentials in Bitwarden and GitHub Secrets as `HETZNER_API_TOKEN` (see [Secret Keys Summary](#secret-keys-summary))

The VPS provisioning and configuration will be handled by the GitHub Actions workflows defined in this repository (`deploy-infra.yml`), so there is no need to manually create VPS instances or configure them at this stage. The workflows will take care of provisioning the VPS, configuring it with Ansible, and deploying the Docker Compose stack.

### Infrastructure Workflow

> **ACTION:** Run the infrastructure provisioning workflow

The configuration for haven is defined in the `config/` directory using Strata's Kubernetes-style schema. Strata reads these YAML files and generates the Terraform artifacts consumed by the deployment workflow.

Infrastructure provisioning is handled by the `deploy-infra.yml` GitHub Actions workflow. This workflow uses the Hetzner API and the deployment SSH key to provision the VPS, apply Terraform changes, and configure S3 storage.

When we first run the deployment workflows, they will provision the infrastructure defined in the Strata configuration. This includes creating the VPS instance for the hearth system, setting up the firewall rules, and configuring the network settings.

GitHub Actions → Select `deploy-infra` → Run workflow. This runs `strata build` + Terraform to provision the VPS, firewall, and network. Use these inputs:

| Input     | Value  | Notes                                |
| --------- | ------ | ------------------------------------ |
| `branch`  | `main` | Your main branch (or feature branch) |
| `dry_run` | `true` | First run: preview changes only      |
| `stage`   | `prod` | Production infrastructure            |
| `run_s3`  | `true` | Provision S3 buckets on first run    |

After reviewing the plan, run again with `dry_run: false` to apply.

> Note the **server IP** from the Terraform output — you need it for DNS A records at INWX.

### Infrastructure DNS Records

> **ACTION:** Add DNS A records at INWX pointing to the server IP provisioned by Terraform.

Once you have the server IP, add the A records at INWX. See [domains.md](./domains.md#dns-records-for-huybrechtsxyz) for the full DNS record list and [inwx.md](./inwx.md#nameserver-configuration) for INWX configuration.

## Hearth Deployment

The Hearth VPS is the core of the Haven platform. It runs Caddy, Authentik, Vaultwarden, Infisical, Portainer, and WUD as a Docker Compose stack. Deployment is handled by the `deploy-hearth.yml` GitHub Actions workflow in three phases: **init → config → deploy**.

> **Prerequisites:** `deploy-infra.yml` must have run successfully (VPS exists), DNS A records must be configured at INWX, and all GitHub Secrets and Environment Variables must be set (see [Secrets and Credential Management](#secrets-and-credential-management)).

> **⚠️ Branch restriction:** The workflow blocks deployments from `main`. Always run from a feature branch (e.g. `deploy/hearth`).

### Hearth Initialisation

> **ACTION:** Run the initialisation phase of the deployment workflow to set up the hearth VPS and generate the BorgBackup SSH key.

The first run bootstraps the bare VPS: creates the deploy user, installs Docker, configures system settings, and generates the BorgBackup SSH key pair on the server.

GitHub Actions → Select `deploy-hearth` → Run workflow from your feature branch:

| Input            | Value           | Notes                                |
| ---------------- | --------------- | ------------------------------------ |
| `branch`         | `deploy/hearth` | Must match the branch you run from   |
| `dry_run`        | `false`         |                                      |
| `run_init`       | `true`          | One-time server initialisation       |
| `configure_borg` | `false`         | Not yet — SSH key not authorised yet |
| `run_config`     | `false`         | Skip on first run                    |
| `run_deploy`     | `false`         | Skip on first run                    |

After this run, **find the BorgBackup public key** in the workflow output (look for `borg_public_key` or similar in the init step logs). You need it for the next manual step.
Store the public key in Bitwarden for reference, but it must be added to the Hetzner Storage Box sub-account for BorgBackup to work.

#### Hearth Initial Setup

Bootstrap the server with Docker, the `haven` service user, directory structure, and SSH hardening.

**Playbook:** `deploy/ansible-init/hearth-init.yml`  
**Runs once** on a fresh server. Safe to re-run — all tasks are idempotent.

| Task                    | Details                                                                    |
| ----------------------- | -------------------------------------------------------------------------- |
| Set timezone            | Configured via `haven_timezone` variable (set in `vars/main.yml`)          |
| Install packages        | `curl`, `ca-certificates`, `gnupg`, `borgbackup`, `fail2ban`, `jq`, others |
| Install Docker          | Official Docker CE repository, pinned version                              |
| Create `haven` user     | System user, home `/opt/haven`, member of `docker` group                   |
| Create directory tree   | `/opt/haven/etc`, `/opt/haven/var/data`, `/opt/haven/var/certs`, etc.      |
| Generate BorgBackup key | `borg_ed25519` SSH key pair in `/opt/haven/.ssh/`                          |
| SSH hardening           | `PermitRootLogin prohibit-password`, `PasswordAuthentication no`           |

#### Hearth Service Directories

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

### Hearth BorgBackup Authorization

> **ACTION:** Authorise the BorgBackup SSH key on the Hetzner Storage Box sub-account. This is required for automated backups to work.

The borg SSH key upload is **automated** — when `configure_borg=true`, the init playbook uploads the generated `borg_ed25519.pub` key to the Storage Box sub-account via `install-ssh-key` (Hetzner's standard SSH key installation command on port 23), using `HETZNER_STORAGEBOX_PASSWORD` for authentication. No manual Robot UI step is required.

> The public key is printed in the Run 1 workflow output for reference — store it in Bitwarden, but you do not need to add it manually via Hetzner Robot.

> **⚠️ External reachability** must be enabled on the sub-account (covered in [Infrastructure Storage Box](#infrastructure-storage-box)). Without it the automated upload on port 23 will fail.

### Hearth Configure and Deploy

> **ACTION:** Run the configuration and deployment phases of the workflow to set up the hearth services.
> **ACTION:** After deployment, save the BorgBackup repokey for future restores.

With the BorgBackup key authorised, run the full deployment: initialise the borg repository on the Storage Box, enforce configuration, and start all Docker Compose services.

GitHub Actions → Select `deploy-hearth` → Run workflow from your feature branch:

| Input            | Value           | Notes                                          |
| ---------------- | --------------- | ---------------------------------------------- |
| `branch`         | `deploy/hearth` | Must match the branch you run from             |
| `dry_run`        | `false`         |                                                |
| `run_init`       | `false`         |                                                |
| `configure_borg` | `true`          | Initialises borg repo on Storage Box           |
| `run_config`     | `true`          | Idempotent config enforcement                  |
| `run_deploy`     | `true`          | Deploys Docker Compose stack                   |
| `full_restart`   | `false`         | Set `true` only if containers have stale state |

After this run, the following services should be reachable at their configured subdomains:

| Service     | URL example                  |
| ----------- | ---------------------------- |
| Caddy       | (reverse proxy — no UI)      |
| Authentik   | `https://auth.{domain}`      |
| Vaultwarden | `https://vault.{domain}`     |
| Infisical   | `https://secrets.{domain}`   |
| Portainer   | `https://portainer.{domain}` |
| WUD         | `https://wud.{domain}`       |

**Running containers** (verify with `docker ps` on the server or via Portainer):

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

**Save the BorgBackup repokey** — in the workflow log, find the task **"Show BorgBackup repokey"** → copy the key block and save to Bitwarden as **"Haven BorgBackup repo key"**.

> ⚠️ Without this key + `BORG_PASSPHRASE`, backups **cannot be restored**. The repokey is also shown on every subsequent `run_config` run (when `configure_borg=true`), so you can retrieve it later if needed.

> **Subsequent deployments** (after config changes): run with `run_init=false`, `configure_borg=false`, `run_config=true`, `run_deploy=true`. Optionally set `backup_before_deploy=true` to snapshot before applying changes.

---

## Hearth Service Configuration

Once Hearth is deployed and all containers are running, configure each service. **Order matters** — Authentik must be configured first since it is used for SSO.

### Setup Caddy

See [caddy.md](./caddy.md) for detailed setup: configuring TLS, reverse proxy routes, and middleware.

Caddy starts automatically and obtains Let's Encrypt certificates on first run (~30 seconds per domain). No manual setup required. To add routes or middleware, edit the `Caddyfile` in `services/hearth/caddy/Caddyfile` and redeploy.

### Setup Authentik

> **⚠️ Configure Authentik first** others require Authentik OIDC providers to be set up before their SSO can work.

See [authentik.md](./authentik.md) for detailed setup: creating the admin account, configuring email (SMTP via Infomaniak), and creating OIDC providers for Vaultwarden, Infisical, WUD, and Portainer.

### Setup Vaultwarden

See [bitwarden.md](./bitwarden.md) for detailed setup: creating the admin account, inviting family members, and configuring OIDC authentication with Authentik.

> ⚠️ You log in to the Vaultwarden admin panel with the **plain-text token** — Vaultwarden verifies it against the stored Argon2 hash internally. The `VAULTWARDEN_ADMIN_TOKEN` GitHub Secret must be the `$argon2id$...` hash, not the plain-text value.

### Setup Infisical

See [infisical.md](./infisical.md) for detailed setup: creating the admin account, configuring email, and setting up OIDC authentication with Authentik.

### Setup Portainer

See [portainer.md](./portainer.md) for detailed setup: creating the admin account and configuring authentication with Authentik.

### Setup WUD (What's Up Docker)

See [wud.md](./wud.md) for detailed setup: configuring authentication with Authentik and setting up update notifications.

### Setup BorgBackup

BorgBackup runs as a daily cron job at 02:00 UTC, backing up Authentik, Vaultwarden, and Infisical volumes plus `/opt/haven/etc` to the Storage Box with `repokey-blake2` encryption.

- **Retention:** 7 daily, 4 weekly, 6 monthly
- **Log:** `/var/log/haven-backup.log`

See [borgbackup.md](./borgbackup.md) for restore instructions and manual backup procedures.

### Setup Healthchecks.io

Healthchecks.io monitors backup cron execution via a dead man's switch — if the backup cron doesn't ping within 25 hours, you get an alert.

See [healthchecks-io.md](./healthchecks-io.md) for detailed setup. The ping URL is already configured via the `HEALTHCHECK_PING_URL_BACKUP` environment variable set in [Environment Variables](#environment-variables).

### Setup UptimeRobot

UptimeRobot provides external uptime monitoring for the public service endpoints (Authentik, Vaultwarden, Infisical).

See [uptimerobot.md](./uptimerobot.md) for detailed setup: creating monitors for each service subdomain.

---

## Forge Deployment

> **⚠️ Forge deployment is not yet implemented.** The `deploy-forge.yml` workflow exists but the Ansible playbooks (`forge-config.yml`, `forge-deploy.yml`) are still TODO. This chapter will be completed when Forge deployment is ready.

Forge will run a k3s cluster on a CPX41 VPS and host Immich, Jellyfin, Gatus, and home-grown apps via Helm charts. It depends on Hearth being fully operational (Authentik for SSO, Infisical for secrets).

---

## Infomaniak

Infomaniak kSuite provides email, calendar, contacts, and file storage for Haven. It is Swiss-hosted and serves as the Tier 2 backup target (daily rclone sync from the Storage Box to kDrive).

See [infomaniak.md](./infomaniak.md) for detailed setup: configuring mailboxes, generating app passwords for Authentik SMTP, and setting up rclone for kDrive backup sync.


