# Haven Setup

> The following steps are required to prepare the Haven platform for deployment. All secrets must be generated and stored in Bitwarden before provisioning infrastructure and services. All variables must be configured in the strata environment configuration.

[← Back to Guide](./index.md)

## Secrets and Credential Management

Generate all secrets once, store every value in Bitwarden, then configure them in GitHub and Terraform Cloud.

### Generate Secrets

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

### GitHub Setup for Infisical Cloud

GitHub only needs a **machine identity** to connect to Infisical Cloud. Once that connection is established, all application secrets are fetched from Infisical at deploy time; nothing else goes in GitHub Secrets.

**Create a machine identity in Infisical Cloud:**

1. [app.infisical.com](https://app.infisical.com) → Organization → Access Control → Machine Identities → Create
2. Name: `haven-github-actions`
3. Auth method: **Universal Auth**
4. Assign to your haven project with `read` role
5. Copy the **Client ID** and **Client Secret** → store in Bitwarden → add to GitHub Secrets

| GitHub Secret             | Value                          | Notes                                                 |
| ------------------------- | ------------------------------ | ----------------------------------------------------- |
| `INFISICAL_CLIENT_ID`     | Machine identity client ID     | Infisical Cloud → Machine Identities → Universal Auth |
| `INFISICAL_CLIENT_SECRET` | Machine identity client secret | Infisical Cloud → Machine Identities → Universal Auth |

**GitHub Variable (non-sensitive):**

| GitHub Variable        | Value                  | Notes                                                 |
| ---------------------- | ---------------------- | ----------------------------------------------------- |
| `INFISICAL_PROJECT_ID` | Infisical project UUID | Settings → Project ID in your haven Infisical project |











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



---

## GitHub Secrets Inventory

Complete list of what goes in GitHub Secrets vs Infisical Cloud.

**Rule:** GitHub Secrets hold only what is needed to provision infrastructure and connect to Infisical. Everything else is an application secret and lives in Infisical Cloud.

### GitHub Secrets (infrastructure bootstrap)

| GitHub Secret             | Value                          | Notes                                                |
| ------------------------- | ------------------------------ | ---------------------------------------------------- |
| `TERRAFORM_API_TOKEN`     | Terraform Cloud API token      | Terraform Cloud → User Settings → Tokens             |
| `HETZNER_API_TOKEN`       | Hetzner Cloud project token    | Hetzner Cloud → Project → Security → API Tokens      |
| `HETZNER_PUBLIC_KEY`      | SSH public key (`.pub`)        | Single line — see SSH key section above              |
| `HETZNER_PRIVATE_KEY`     | SSH private key (full content) | Including `-----BEGIN/END-----` lines                |
| `HETZNER_ROOT_PASSWORD`   | Random password                | `token_urlsafe(32)` — initial root access only       |
| `HETZNER_S3_ACCESS_KEY`   | S3 access key ID               | Hetzner Object Storage — project-level (all buckets) |
| `HETZNER_S3_SECRET_KEY`   | S3 secret access key           | Hetzner Object Storage — project-level (all buckets) |
| `INFISICAL_CLIENT_ID`     | Machine identity client ID     | To connect GitHub Actions to Infisical Cloud         |
| `INFISICAL_CLIENT_SECRET` | Machine identity client secret | To connect GitHub Actions to Infisical Cloud         |

### Infisical Cloud Secrets (application secrets)

Stored in Infisical Cloud → haven project → `prod` environment. Fetched at deploy time via machine identity. Store every value in Bitwarden as well (backup copy).

| Infisical Key                   | Value                    | Notes                                                      |
| ------------------------------- | ------------------------ | ---------------------------------------------------------- |
| `AUTHENTIK_SECRET_KEY`          | Random string (86 chars) | `token_urlsafe(64)`                                        |
| `AUTHENTIK_POSTGRESQL_PASSWORD` | Random password          | `token_urlsafe(32)`                                        |
| `AUTHENTIK_EMAIL__USERNAME`     | SMTP username            | kSuite email — see [infomaniak.md](./infomaniak.md)        |
| `AUTHENTIK_EMAIL__PASSWORD`     | SMTP app password        | kSuite app password — see [infomaniak.md](./infomaniak.md) |
| `VAULTWARDEN_ADMIN_TOKEN`       | Argon2 hashed token      | See note below                                             |
| `VAULTWARDEN_SSO_CLIENT_SECRET` | OIDC client secret       | `token_urlsafe(48)` — used in Authentik provider setup     |
| `WUD_SSO_CLIENT_SECRET`         | OIDC client secret       | `token_urlsafe(48)` — used in Authentik provider setup     |
| `BORG_PASSPHRASE`               | Random passphrase        | `token_urlsafe(48)`                                        |
| `STORAGEBOX_HOST`               | Storage Box hostname     | e.g. `uXXXXXX.your-storagebox.de`                          |
| `STORAGEBOX_SUBACCOUNT`         | Storage Box sub-account  | e.g. `uXXXXXX-sub1`                                        |
| `STORAGEBOX_PASSWORD`           | Sub-account password     | Set when creating sub-account in Hetzner Robot             |
| `HEALTHCHECK_PING_URL`          | Healthchecks.io ping URL | Dead man's switch for backup monitoring                    |

> **Vaultwarden admin token** must be Argon2-hashed before storing. Generate with:
> ```powershell
> python -c "import secrets; print(secrets.token_urlsafe(48))"
> # Then hash it: docker run --rm vaultwarden/server /vaultwarden hash --preset owasp
> ```
> Store the **plaintext token** in Bitwarden (you need it to log in); store the **hashed value** in Infisical.

