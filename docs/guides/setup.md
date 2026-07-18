# Haven Setup

> The following steps are required to prepare the Haven platform for deployment. All secrets must be generated and stored in Bitwarden before provisioning infrastructure and services. All variables must be configured in the strata environment configuration.

[← Back to Guide](./index.md)

## Secrets and Credential Management

Generate all secrets once, store every value in Bitwarden, then configure them in GitHub and Terraform Cloud.

### Secrets Overview

Complete list of what goes in GitHub Secrets vs Infisical Cloud.

**Rule:** GitHub Secrets hold only what is needed to connect to Infisical. Everything else is a secret that lives in Infisical Cloud.

**GitHub Secrets** are Used by GitHub Actions to provision infrastructure and connect to Infisical Cloud. Store the secrets in Bitwarden, then add them to GitHub Secrets.

| GitHub Secret             | Value                          | Notes                                                 |
| ------------------------- | ------------------------------ | ----------------------------------------------------- |
| `INFISICAL_CLIENT_ID`     | Machine identity client ID     | Infisical Cloud → Machine Identities → Universal Auth |
| `INFISICAL_CLIENT_SECRET` | Machine identity client secret | Infisical Cloud → Machine Identities → Universal Auth |

**GitHub Variables** are non-sensitive values used by GitHub Actions. Store the values in Bitwarden, then add them to GitHub Variables.

| GitHub Variable        | Value                  | Notes                                                 |
| ---------------------- | ---------------------- | ----------------------------------------------------- |
| `INFISICAL_PROJECT_ID` | Infisical project UUID | Settings → Project ID in your haven Infisical project |

**Infisical Secrets** are secrets stored in Infisical Cloud. All secrets are fetched at runtime via machine identity (Universal Auth). Store every value in Bitwarden as a backup.

| Infisical Key               | Value             | Notes                                                              |
| --------------------------- | ----------------- | ------------------------------------------------------------------ |
| **Hetzner**                 |                   |                                                                    |
| `HETZNER_API_TOKEN`         | API token         | Hetzner Cloud project token                                        |
| `HETZNER_PRIVATE_KEY`       | Private Key       | Hetzner SSH deployment key (ed25519)                               |
| `HETZNER_PUBLIC_KEY`        | Public Key        | Hetzner SSH deployment key (ed25519)                               |
| `HETZNER_S3_ACCESS_KEY`     | Access Key ID     | Hetzner Object Storage — project-level (all buckets)               |
| `HETZNER_S3_SECRET_KEY`     | Secret Access Key | Hetzner Object Storage — project-level (all buckets)               |
| `HETZNER_ROOT_PASSWORD`     | Random password   | `token_urlsafe(32)` — initial root access only                     |
|                             |                   |                                                                    |
| **Storagebox**              |                   |                                                                    |
| `STORAGEBOX_HOST_MAIN`      | Configuration     | e.g. `uXXXXXX.your-storagebox.de`- Storage Box URL                 |
| `STORAGEBOX_HOST_HEART`     | Configuration     | e.g. `uXXXXXX.your-storagebox.de`- Storage Box URL                 |
| `STORAGEBOX_HOST_FORGE`     | Configuration     | e.g. `uXXXXXX.your-storagebox.de`- Storage Box URL                 |
| `STORAGEBOX_HEART_PASSWORD` | Password          | Sub-account password set on creation subaccount                    |
| `STORAGEBOX_FORGE_PASSWORD` | Password          | Sub-account password set on creation subaccount                    |
|                             |                   |                                                                    |
| **Borg backup**             |                   |                                                                    |
| `BORG_PASSPHRASE_HEART`     | Passphrase        | `token_urlsafe(48)` — Used to encrypt/decrypt Borg backup archives |
| `BORG_PASSPHRASE_FORGE`     | Passphrase        | `token_urlsafe(48)` — Used to encrypt/decrypt Borg backup archives |
|                             |                   |                                                                    |
| **Terraform**               |                   |                                                                    |
| `TERRAFORM_API_TOKEN`       | API token         | Terraform Cloud API token                                          |

### Generating Secrets

> Note. Strata can generate random secrets for you during provisioning. So no extra tools are needed.
> You do need to generate the secrets at least once and store them in Bitwarden and Infisical Cloud,

**Generate random secrets using Python's `secrets` module:**

```powershell
# Using Python's secrets module (available in all Python installations)
python -c "from secrets import token_urlsafe, token_hex; print('urlsafe(64):', token_urlsafe(64)); print('hex(32):', token_hex(32))"

# Or use Strata if available
strata secret generate --length 64 --format urlsafe
strata secret generate --length 64 --format hex
```

### Infisical Cloud Setup

> **ACTION:** Create a new project in Infisical Cloud for Haven. Store the project ID in Bitwarden and GitHub Variables.

**Create a machine identity in Infisical Cloud:**

1. [app.infisical.com](https://app.infisical.com) → Organization → Access Control → Machine Identities → Create
2. Name: `haven-github-actions`
3. Auth method: **Universal Auth**
4. Assign to your haven project with `read` role
5. Copy the **Client ID** and **Client Secret** → store in Bitwarden → add to GitHub Secrets

### Secrets for Hetzner API Token

> **ACTION:** Generate a Hetzner Cloud project token. Store it in Bitwarden and Infisical Cloud.

### Secrets for Hetzner SSH Deployment Key

> **ACTION:** Generate an ed25519 SSH key pair. Store the public key in the Hetzner Cloud project and the private key in Bitwarden. Create Infisical secrets.

Create an ed25519 SSH key pair for deployment. The public key goes to Hetzner (for Terraform provisioning and BorgBackup), the private key goes to Infisical Cloud and Bitwarden. You can generate the key pair using PowerShell or any SSH key generation tool. Bitwarden also has a built-in SSH key generator that can create and store the key pair directly in your vault.

```powershell
# Generate ed25519 SSH key pair
ssh-keygen -t ed25519 -C "haven-deploy" -f ~/.ssh/haven_ed25519 -N ""

# Public key → Hetzner Cloud project
Get-Content ~/.ssh/haven_ed25519.pub

# Private key → Infisical Cloud
Get-Content ~/.ssh/haven_ed25519 -Raw
```

### Secrets for Hetzner S3 Object Storage

> **ACTION:** Generate an S3 access key pair in the Hetzner Cloud console. Store the Access Key ID and Secret Access Key in Bitwarden and Infisical Cloud.

Hetzner Object Storage uses S3-compatible credentials at the **project level** — one key pair grants access to all buckets in the project. There are no per-bucket IAM policies or scoped keys.

Four buckets are provisioned by the `ansible-s3/forge-s3.yml` playbook:

- `haven-photos` — Immich external photo library
- `haven-media` — media overflow (large binary assets)
- `haven-archive` — cold storage, documents, exports
- `haven-docs` — documentation and operational exports

1. [console.hetzner.cloud](https://console.hetzner.cloud) → Project → Object Storage → Access Keys → Create access key
2. Create **one** key pair (used by the CI/CD pipeline to provision buckets and by apps to read/write them)
3. Copy the **Access Key ID** and **Secret Access Key** immediately — the secret is only shown once
4. Store both values in Bitwarden and Infisical Cloud

> The secret key is only displayed once at creation time. If lost, delete the key and create a new one.
> Additional key pairs can be created (e.g. a separate pair for rclone offsite sync) but each still has project-wide access — Hetzner does not support bucket-scoped keys.

### Secrets for Terraform Cloud API Token

> **ACTION:** Generate a Terraform Cloud API token. Store it in Bitwarden and Infisical Cloud.
