# Haven Infrastructure Guide

> This guide describes the infrastructure provisioning and configuration for the Haven platform. It is intended for the administrator and assumes familiarity with GitHub, Terraform, Ansible, Docker Compose, and k3s.

[← Back to Guide](./guide.md)

## Infrastructure Setup

Hetzner Cloud is the VPS hosting provider for haven. You will need to create a project, generate an API token, and add the SSH public key for deployment.

### Infrastructure Storage Box

> **ACTION:** Set up a Hetzner Storage Box for off-site backups. Create sub-accounts for the hearth and forge systems, enable external reachability, and store the credentials in Bitwarden and GitHub Secrets.

The storage box is where BorgBackup will store encrypted backups of the hearth system. Hetzner Storage Boxes do not have an API, so this step must be done manually through the Hetzner interface.

Follow these steps to set up the storage box:

1. Sign in at [robot.hetzner.com](https://robot.hetzner.com) (same Hetzner account)
2. Order a **BX11** Storage Box (1 TB, Nuremberg region)
3. Once activated, go to Storage Box settings → Sub-accounts
4. Create the **Hearth sub-account** (e.g. `{storagebox-id}-hearth`), set a password, enable SSH access
5. Create the **Forge sub-account** (e.g. `{storagebox-id}-forge`), set a password, enable SSH access
6. Enable **External reachability** on **both** sub-accounts (required for port 23 access from VPS public IP)
7. Note the hostname (e.g. `{storagebox-id}.your-storagebox.de`) and both sub-account usernames
8. Store credentials in Bitwarden: both passwords go in as `HETZNER_STORAGEBOX_PASSWORD` (same secret; use the Hearth one for now, update when Forge is added)
9. Add Variables to the Strata environment configuration:
   - `STORAGEBOX_HOST` = hostname
   - `STORAGEBOX_SUBACCOUNT_HEARTH` = hearth sub-account username (e.g. `{storagebox-id}-hearth`)
   - `STORAGEBOX_SUBACCOUNT_FORGE` = forge sub-account username (e.g. `{storagebox-id}-forge`)

> **⚠️ Hetzner Storage Boxes have no API or Terraform provider. This step is entirely manual and cannot be automated.**
> **⚠️ External reachability must be enabled** — without it, only Hetzner-internal traffic can reach port 23. The VPS connects via its public IP, so BorgBackup will time out if this is off.

### Infrastructure S3 Object Storage

> **ACTION:** Generate an S3 access key pair in the Hetzner Cloud console and store the credentials. The buckets themselves are provisioned automatically by the `deploy-infra.yml` workflow.

Hetzner Object Storage provides S3-compatible buckets for photos, media, archives, and documents. Credentials are project-level — one key pair grants access to all buckets. There are no per-bucket IAM policies or scoped keys.

**Buckets** (provisioned by `deploy/ansible-s3/forge-s3.yml`):

| Bucket          | Purpose                               |
| --------------- | ------------------------------------- |
| `haven-photos`  | Immich external photo library         |
| `haven-media`   | Media overflow (large binary assets)  |
| `haven-archive` | Cold storage, documents, exports      |
| `haven-docs`    | Documentation and operational exports |

**Steps:**

1. [console.hetzner.cloud](https://console.hetzner.cloud) → Project → Object Storage → Access Keys → Create access key
2. Copy the **Access Key ID** and **Secret Access Key** immediately — the secret is only shown once
3. Store both values in Bitwarden and GitHub Secrets:

| GitHub Secret           | Value             | Notes                                                |
| ----------------------- | ----------------- | ---------------------------------------------------- |
| `HETZNER_S3_ACCESS_KEY` | Access Key ID     | Hetzner Object Storage — project-level (all buckets) |
| `HETZNER_S3_SECRET_KEY` | Secret Access Key | Hetzner Object Storage — project-level (all buckets) |

> The secret key is only displayed once at creation time. If lost, delete the key and create a new one.

The buckets are created/updated when the `deploy-infra.yml` workflow runs with `run_s3: true`. This is idempotent and safe to re-run.

### Infrastructure Connectivity

> **ACTION:** Set up the Hetzner Cloud project for haven. Add the SSH public key for deployment and generate an API token for Terraform provisioning.

The Haven system runs on a set of VPS instances hosted on Hetzner Cloud. The main instance is the "hearth" VPS, which runs the core services in a Docker Compose stack. The "forge" VPS is used for additional services and workloads. Follow these steps to set up the infrastructure hosting (assumes the Hetzner project is already created, see [Prerequisites → Hetzner](./services/hetzner.md#initial-setup)):

1. Go to Security → SSH Keys → Add SSH key → Paste the PUBLIC key from the Hetzner SSH Deployment Key
   > This key is registered at **project level** — Terraform will inject it into every VPS it creates (Hearth, Forge, any future nodes). One key pair covers all servers.
2. Go to Security → API Tokens → Create token → Name: "Haven Deploy" → Permissions: Read/Write
3. Store credentials in Bitwarden and GitHub Secrets as `HETZNER_API_TOKEN` (see [Secret Keys Summary](#secret-keys-summary))

The VPS provisioning and configuration will be handled by the GitHub Actions workflows defined in this repository (`deploy-infra.yml`), so there is no need to manually create VPS instances or configure them at this stage. The workflows will take care of provisioning the VPS, configuring it with Ansible, and deploying the Docker Compose stack.

### Infrastructure Workflow

> **ACTION:** Run the infrastructure provisioning workflow
> **RESULT:** The VPS are provisioned, firewall rules are applied, and the network is configured.

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

Once you have the server IP, add the A records at INWX. See [domains.md](./guide-domains.md#dns-records-for-base-domain) for the full DNS record list and [inwx.md](./inwx.md#nameserver-configuration) for INWX configuration.
