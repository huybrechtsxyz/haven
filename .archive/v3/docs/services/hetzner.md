# Hetzner Cloud

Hetzner Cloud is the hosting provider for the haven platform. The infrastructure is provisioned using OpenTofu and configured using Ansible, with deployment automation via GitHub Actions.

StorageBoxes are used for off-site backups with BorgBackup. The deployment workflow includes specific steps to manage Hetzner firewalls for secure SSH access during provisioning and restore operations.

## Initial Setup

1. Sign up for a Hetzner Cloud account at <https://console.hetzner.cloud>.
2. Enable MFA immediately after account creation:
   - Go to Account → Security → Two-factor authentication
   - Scan QR code with **Bitwarden Authenticator**
   - Store the TOTP seed and recovery code in **Bitwarden cloud** (not Vaultwarden)
3. Store the Hetzner account credentials in **Bitwarden cloud**.
4. Create a project named "Haven" to group all related resources (VMs, firewalls, storage boxes).

## Create a Hetzner Cloud API token

1. Go to Account → Security → API Tokens → Create API Token
2. Name the token "Haven" and select **Read & Write** permissions.
3. Store the token in **Bitwarden cloud** and **Infisical Cloud** as a secret.

## Create a Hetzner Cloud SSH key pair

Easiest way to generate a SSH key pair is using Bitwarden's built-in SSH key generator using the UI.

Store the public key in the Hetzner Cloud project and the private key in **Bitwarden cloud**. Create Infisical secrets for the private key and the public key.

## Create a Hetzner Cloud StorageBox

The storage box is where BorgBackup stores encrypted backups of the hearth and forge systems. Hetzner Storage Boxes have **no API or Terraform provider** — this step is entirely manual and cannot be automated.

1. [robot.hetzner.com](https://robot.hetzner.com) → order a **BX11** Storage Box (1 TB, Nuremberg region)
2. Once activated, go to Storage Box settings → Sub-accounts → Create sub-account
3. Create one sub-account per node (e.g. `{storagebox-id}-sub1` for hearth, `{storagebox-id}-sub2` for forge), set a password, enable SSH access
4. Enable **External reachability** on **both** sub-accounts — required for port 23 access from the VPS public IP. Without it, only Hetzner-internal traffic can reach the box and BorgBackup will time out.
5. Note the main hostname (`{storagebox-id}.your-storagebox.de`) and each sub-account's own hostname — sub-accounts get their own hostname following the pattern `{storagebox-id}-sub1.your-storagebox.de`, `{storagebox-id}-sub2.your-storagebox.de`
6. Store each sub-account password in Bitwarden and Infisical

## Create Hetzner Cloud S3 Access Keys

Hetzner Object Storage provides S3-compatible buckets. Credentials are **project-level** — one key pair grants access to all buckets in the project. There are no per-bucket IAM policies or scoped keys.

1. [console.hetzner.cloud](https://console.hetzner.cloud) → Project → Object Storage → Access Keys → Create access key
2. Create **one** key pair (used by the CI/CD pipeline to provision buckets and by apps to read/write them)
3. Copy the **Access Key ID** and **Secret Access Key** immediately — the secret is only shown once. If lost, delete the key and create a new one.
4. Store both values in Bitwarden and Infisical Cloud

> Additional key pairs can be created (e.g. a separate pair for rclone offsite sync) but each still has project-wide access — Hetzner does not support bucket-scoped keys.
