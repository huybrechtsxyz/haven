

---

### GitHub Secrets Inventory

**Phase 1 — GitHub Secrets (bootstrap only — minimum to provision infrastructure and start Infisical):**

These secrets are required for GitHub Actions to provision infrastructure, connect via SSH, and bootstrap Infisical. Once Infisical is running, it becomes the secret store for all application secrets. A machine identity (Universal Auth) is used by CI to fetch secrets from Infisical at deploy time.

> **ACTION:** Generate all secrets using the commands above, then store them in Bitwarden under a "Haven Secrets" entry. Create fields for each secret and add notes about their purpose.

| GitHub Secret                   | Value                          | Notes                                                       |
| ------------------------------- | ------------------------------ | ----------------------------------------------------------- |
| `TERRAFORM_API_TOKEN`           | Terraform Cloud API token      | Created in Terraform Cloud → User Settings → Tokens         |
| `HETZNER_API_TOKEN`             | Hetzner Cloud project token    | Created in Hetzner Cloud → Project → Security → API Tokens  |
| `HETZNER_PUBLIC_KEY`            | SSH public key (`.pub`)        | Single line — see SSH key section above                     |
| `HETZNER_PRIVATE_KEY`           | SSH private key (full content) | Including `-----BEGIN/END-----` lines                       |
| `HETZNER_ROOT_PASSWORD`         | Random password                | `token_urlsafe(32)` — initial root access only              |
| `INFISICAL_AUTH_SECRET`         | 64 hex chars                   | `token_hex(32)` — Infisical must have this before it starts |
| `INFISICAL_ENCRYPTION_KEY`      | **32 chars exactly**           | `token_hex(16)` — not 64!                                   |
| `INFISICAL_POSTGRESQL_PASSWORD` | Random password                | `token_urlsafe(32)`                                         |
| `INFISICAL_CLIENT_ID`           | Machine identity client ID     | Created in Infisical → Machine Identities → Universal Auth  |
| `INFISICAL_CLIENT_SECRET`       | Machine identity client secret | Created in Infisical → Machine Identities → Universal Auth  |
| `HETZNER_S3_ACCESS_KEY`         | Hetzner S3 access key ID       | Object Storage — project-level, all buckets                 |
| `HETZNER_S3_SECRET_KEY`         | Hetzner S3 secret access key   | Object Storage — project-level, all buckets                 |

**GitHub Variables (non-sensitive):**

| GitHub Variable        | Value                  | Notes                                                |
| ---------------------- | ---------------------- | ---------------------------------------------------- |
| `INFISICAL_PROJECT_ID` | Infisical project UUID | The project containing all haven application secrets |

### Infisical Secrets (fetched at runtime)

**Phase 2 — Application secrets stored in Infisical (prod environment):**

Once Infisical is running on Hearth, all application secrets are managed there. The deploy-hearth workflow authenticates via machine identity (Universal Auth) and fetches these at runtime. Store every value in both Bitwarden (backup) and Infisical.

| Infisical Key                   | Value                            | Notes                                                                                                    |
| ------------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `AUTHENTIK_SECRET_KEY`          | Random string (86 chars)         | `token_urlsafe(64)`                                                                                      |
| `AUTHENTIK_POSTGRESQL_PASSWORD` | Random password                  | `token_urlsafe(32)`                                                                                      |
| `VAULTWARDEN_ADMIN_TOKEN`       | Argon2 hashed token              | See note below                                                                                           |
| `VAULTWARDEN_SSO_CLIENT_SECRET` | Pre-generated OIDC client secret | `token_urlsafe(48)` — used in Authentik provider setup                                                   |
| `WUD_SSO_CLIENT_SECRET`         | Pre-generated OIDC client secret | `token_urlsafe(48)` — used in Authentik provider setup                                                   |
| `BORG_PASSPHRASE`               | Random passphrase                | `token_urlsafe(48)`                                                                                      |
| `STORAGEBOX_HOST`               | Storage Box hostname             | e.g. `uXXXXXX.your-storagebox.de`                                                                        |
| `STORAGEBOX_SUBACCOUNT`         | Storage Box sub-account          | e.g. `uXXXXXX-sub1`                                                                                      |
| `STORAGEBOX_PASSWORD`           | Storage Box sub-account password | Set when creating sub-account in Hetzner Robot                                                           |
| `HEALTHCHECK_PING_URL`          | Healthchecks.io ping URL         | Dead man's switch for backup monitoring                                                                  |
| `AUTHENTIK_EMAIL__USERNAME`     | SMTP username (kSuite email)     | See [infomaniak.md → SMTP Server Configuration](./infomaniak.md#smtp-server-configuration-for-authentik) |
| `AUTHENTIK_EMAIL__PASSWORD`     | SMTP app password                | See [infomaniak.md → SMTP Server Configuration](./infomaniak.md#smtp-server-configuration-for-authentik) |

### Secrets Summary

All secrets are generated once and stored in Bitwarden. Infrastructure bootstrap secrets go to GitHub Secrets; application secrets go to Infisical.

| Secret                          | Store     | Value                          | Notes                                   |
| ------------------------------- | --------- | ------------------------------ | --------------------------------------- |
| `TERRAFORM_API_TOKEN`           | GitHub    | Terraform Cloud API token      | Created by Terraform Cloud user         |
| `HETZNER_API_TOKEN`             | GitHub    | Hetzner Cloud project token    | Read/write                              |
| `HETZNER_PUBLIC_KEY`            | GitHub    | SSH public key (`.pub`)        | Single line                             |
| `HETZNER_PRIVATE_KEY`           | GitHub    | SSH private key (full content) | Including `-----BEGIN/END-----` lines   |
| `HETZNER_ROOT_PASSWORD`         | GitHub    | Random password                | `token_urlsafe(32)` — initial root only |
| `HETZNER_S3_ACCESS_KEY`         | GitHub    | S3 access key ID               | Object Storage — project-level          |
| `HETZNER_S3_SECRET_KEY`         | GitHub    | S3 secret access key           | Object Storage — project-level          |
| `INFISICAL_AUTH_SECRET`         | GitHub    | 64 hex chars                   | `token_hex(32)` — bootstrap             |
| `INFISICAL_ENCRYPTION_KEY`      | GitHub    | **32 chars exactly**           | `token_hex(16)` — not 64!               |
| `INFISICAL_POSTGRESQL_PASSWORD` | GitHub    | Random password                | `token_urlsafe(32)` — bootstrap         |
| `INFISICAL_CLIENT_ID`           | GitHub    | Machine identity client ID     | Universal Auth                          |
| `INFISICAL_CLIENT_SECRET`       | GitHub    | Machine identity client secret | Universal Auth                          |
| `AUTHENTIK_SECRET_KEY`          | Infisical | Random string (86 chars)       | `token_urlsafe(64)`                     |
| `AUTHENTIK_POSTGRESQL_PASSWORD` | Infisical | Random password                | `token_urlsafe(32)`                     |
| `VAULTWARDEN_ADMIN_TOKEN`       | Infisical | Argon2 hashed token            | See note below                          |
| `VAULTWARDEN_SSO_CLIENT_SECRET` | Infisical | OIDC client secret             | `token_urlsafe(48)`                     |
| `WUD_SSO_CLIENT_SECRET`         | Infisical | OIDC client secret             | `token_urlsafe(48)`                     |
| `BORG_PASSPHRASE`               | Infisical | Random passphrase              | `token_urlsafe(48)`                     |
| `STORAGEBOX_HOST`               | Infisical | Storage Box hostname           | e.g. `uXXXXXX.your-storagebox.de`       |
| `STORAGEBOX_SUBACCOUNT`         | Infisical | Storage Box sub-account        | e.g. `uXXXXXX-sub1`                     |
| `STORAGEBOX_PASSWORD`           | Infisical | Sub-account password           | Set when creating sub-account           |
| `HEALTHCHECK_PING_URL`          | Infisical | Healthchecks.io ping URL       | Dead man's switch for backups           |
| `AUTHENTIK_EMAIL__USERNAME`     | Infisical | SMTP username                  | kSuite email                            |
| `AUTHENTIK_EMAIL__PASSWORD`     | Infisical | SMTP app password              | kSuite app password                     |
