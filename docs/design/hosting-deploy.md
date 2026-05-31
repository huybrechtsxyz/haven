# Haven Deployment Guide

> How to deploy the Haven family platform from zero to running.

## Prerequisites

| Tool                 | Version | Install                                                                              |
| -------------------- | ------- | ------------------------------------------------------------------------------------ |
| strata               | v0.0.4+ | `uv tool install xyz-strata` or `pip install xyz-strata`                             |
| OpenTofu / Terraform | >= 1.6  | [opentofu.org](https://opentofu.org/docs/intro/install/) or `choco install opentofu` |
| Ansible              | >= 2.14 | `pip install ansible-core`                                                           |
| GitHub CLI           | latest  | `winget install GitHub.cli`                                                          |

## Accounts Required

| Service         | What you need                                               | Where                                                  |
| --------------- | ----------------------------------------------------------- | ------------------------------------------------------ |
| Hetzner Cloud   | Project `haven` + API token (read/write)                    | [console.hetzner.cloud](https://console.hetzner.cloud) |
| Hetzner Robot   | Storage Box order (manual, no API)                          | [robot.hetzner.com](https://robot.hetzner.com)         |
| Terraform Cloud | Organization `huybrechts-xyz`, workspace `haven_deploy_prd` | [app.terraform.io](https://app.terraform.io)           |
| GitHub          | Repository secrets configured                               | Settings → Secrets → Actions                           |
| INWX            | Domain registrar (huybrechts.xyz)                           | [my.inwx.de](https://my.inwx.de)                       |

## Step 1 — Generate SSH Key Pair

**Option A — Bitwarden (recommended):**

1. In Bitwarden: Add item → SSH Key → Generate ed25519 key
2. Bitwarden's SSH agent will serve the key locally (no `~/.ssh/` file needed)
3. Export the public and private key values for GitHub Secrets (Step 2)

**Option B — Local key file:**

```bash
ssh-keygen -t ed25519 -C "haven-deploy" -f ~/.ssh/haven_ed25519 -N ""
```

Either way, the public key goes to Hetzner and the private key to GitHub Secrets.

## Step 2 — Configure GitHub Secrets

Go to your repo → Settings → Secrets and variables → Actions. Add:

| Secret name             | Value                                               |
| ----------------------- | --------------------------------------------------- |
| `TERRAFORM_API_TOKEN`   | Terraform Cloud API token                           |
| `HETZNER_API_TOKEN`     | Hetzner Cloud project API token                     |
| `HETZNER_PUBLIC_KEY`    | SSH public key (from Bitwarden or `.pub` file)      |
| `HETZNER_PRIVATE_KEY`   | SSH private key (from Bitwarden or key file)        |
| `HETZNER_ROOT_PASSWORD` | Strong random password (initial provisioning only)  |
| `INFISICAL_ESO_TOKEN`   | Leave empty for Wave 1 (needed for Forge/k3s later) |

## Step 3 — Configure Terraform Cloud

1. Create organization `huybrechts-xyz`
2. Create workspace `haven_deploy_prd` (must match deployment name in strata config)
3. Set execution mode to **Local** (CLI drives the runs, TF Cloud stores state only)
4. Generate a user/team API token → use as `TERRAFORM_API_TOKEN` GitHub Secret

## Step 4 — Create Hetzner Cloud Project

1. Log in to [Hetzner Cloud Console](https://console.hetzner.cloud)
2. Create project: `haven`
3. Go to Security → API Tokens → Generate token (read/write) → use as `HETZNER_API_TOKEN`

## Step 5 — Order Storage Box (Manual)

> **⚠️ This step is entirely manual.** Hetzner Storage Boxes are managed through
> [Hetzner Robot](https://robot.hetzner.com), which has **no API, no CLI, and no
> Terraform provider**. There is no way to automate this — it is a one-time
> manual order through the web panel.

1. Go to [robot.hetzner.com](https://robot.hetzner.com) → Storage Box
2. Order **BX11** (1 TB, ~€3.81/mo), location: **Nuremberg**
3. Once active, create sub-accounts:
   - `hearth_backup` — BorgBackup target for Hearth VPS
   - `forge_backup` — BorgBackup target for Forge VPS (Wave 2)
4. Enable **SSH access** on both sub-accounts
5. Note the hostname (e.g., `uXXXXXX.your-storagebox.de`) — needed for Ansible bootstrap

The strata config file `config/hearth/sb-hetzner-hearth.yaml` documents the
Storage Box specification for inventory purposes, but does **not** provision it.

## Step 6 — Local Deployment (First Time)

For the initial deployment, run locally to verify everything works:

```powershell
cd e:\SourcesXYZ\haven

# Authenticate Terraform Cloud
terraform login

# Build strata artifacts
strata build run -f config/deploy-haven-prd.yaml

# Copy tfvars to terraform directory
Copy-Item build\haven_deploy_prd-1.0.0\terraform\*.auto.tfvars.json terraform\

# Export secrets as environment variables
$env:TF_VAR_HETZNER_API_TOKEN = "your-token"
$env:TF_VAR_HETZNER_PUBLIC_KEY = Get-Content ~/.ssh/haven_ed25519.pub
$env:TF_VAR_HETZNER_PRIVATE_KEY = Get-Content ~/.ssh/haven_ed25519 -Raw
$env:TF_VAR_HETZNER_ROOT_PASSWORD = "your-password"
$env:TF_VAR_INFISICAL_ESO_TOKEN = ""

# Init + Plan
cd terraform
terraform init
terraform plan

# Apply (creates Hearth VPS + network + firewall)
terraform apply
```

After apply, note the outputs:
- `hearth_public_ip` — point DNS here
- `hearth_private_ip` — internal network address

## Step 7 — Configure DNS

In INWX (or wherever DNS is managed), create A records:

| Record                   | Value                                         |
| ------------------------ | --------------------------------------------- |
| `huybrechts.xyz`         | `<hearth_public_ip>`                          |
| `auth.huybrechts.xyz`    | `<hearth_public_ip>`                          |
| `vault.huybrechts.xyz`   | `<hearth_public_ip>`                          |
| `secrets.huybrechts.xyz` | `<hearth_public_ip>`                          |
| `status.huybrechts.xyz`  | `<hearth_public_ip>`                          |
| `photos.huybrechts.xyz`  | `<hearth_public_ip>` (proxied to Forge later) |

TTL: 300 (5 min) initially, increase to 3600 after verification.

## Step 8 — Bootstrap Hearth (Ansible)

> Wave 1 — this step is still being built (deploy/ansible/ not yet created)

The ansible playbook will:
1. SSH to Hearth using the deploy key
2. Install Docker + Docker Compose
3. Deploy the Caddy + Authentik + Vaultwarden + Infisical stack
4. Configure Caddy with ACME (Let's Encrypt) for all subdomains
5. Set up BorgBackup to the Storage Box

```bash
ansible-playbook -i <hearth_public_ip>, deploy/ansible/hearth-bootstrap.yml \
  --private-key ~/.ssh/haven_ed25519 \
  -u root
```

## Step 9 — Verify

- [ ] `https://huybrechts.xyz` — Caddy responds
- [ ] `https://auth.huybrechts.xyz` — Authentik login page
- [ ] `https://vault.huybrechts.xyz` — Vaultwarden web vault
- [ ] `https://secrets.huybrechts.xyz` — Infisical dashboard
- [ ] SSH via private network only (public SSH blocked by firewall)
- [ ] BorgBackup cron runs successfully

## Step 10 — Enable CI/CD

Once manual deployment works:

1. Push to `main` — the workflow triggers automatically
2. Or run manually: Actions → Deploy Haven → Run workflow
3. Use dry_run=true for plan-only runs
4. Use stage filter to limit scope (e.g., `infrastructure` only)

## Architecture Reference

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
│  │   CX22      │   private net      │    CPX41     │   │
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

## Cost Summary

| Resource             | Monthly                |
| -------------------- | ---------------------- |
| Hearth CX22          | ~€4.15                 |
| Forge CPX41 (Wave 2) | ~€26.00                |
| Storage Box BX11     | ~€3.81                 |
| Terraform Cloud      | Free (< 500 resources) |
| **Total Wave 1**     | **~€7.96**             |
| **Total Wave 1+2**   | **~€33.96**            |

## What's Next (Wave 2)

1. Uncomment Forge module in `terraform/main.tf`
2. Add Forge resource + firewall to strata config
3. Create `deploy/ansible/forge-bootstrap.yml` (k3s install)
4. Create `deploy/helm/` charts for Immich, Gatus
5. Configure Infisical ESO on Forge
6. Update DNS to proxy photos.huybrechts.xyz through Caddy → Forge
