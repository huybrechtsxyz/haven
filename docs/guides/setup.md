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

| GitHub Variable                | Value                  | Notes                                                                               |
| ------------------------------ | ---------------------- | ----------------------------------------------------------------------------------- |
| `INFISICAL_PROJECT_ID`         | Infisical project UUID | Settings → Project ID in your haven Infisical project                               |
| `STORAGEBOX_HOST`              | Configuration          | e.g. `uXXXXXX.your-storagebox.de` — Storage Box hostname (shared by Hearth + Forge) |
| `STORAGEBOX_SUBACCOUNT_HEARTH` | Configuration          | e.g. `uXXXXXX-sub1` — Storage Box sub-account username for Hearth backups           |
| `STORAGEBOX_SUBACCOUNT_FORGE`  | Configuration          | e.g. `uXXXXXX-sub2` — Storage Box sub-account username for Forge backups            |

**Infisical Secrets** are secrets stored in Infisical Cloud. All secrets are fetched at runtime via machine identity (Universal Auth). Store every value in Bitwarden as a backup.

| Infisical Key                    | Value             | Notes                                                                                                                                                                                                               |
| -------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Hetzner**                      |                   |                                                                                                                                                                                                                     |
| `HETZNER_API_TOKEN`              | API token         | Created in Hetzner Cloud → Project → Security → API Tokens                                                                                                                                                          |
| `HETZNER_PRIVATE_KEY`            | Private Key       | Hetzner SSH deployment key (ed25519)                                                                                                                                                                                |
| `HEARTH_SSH_PRIVATE_KEY`         | Private Key       | Same value as `HETZNER_PRIVATE_KEY` — reused under this name to satisfy a separate (legacy) Terraform variable in `deploy/terraform/variables.tf`. Do not store a second key; point it at the same Infisical value. |
| `HETZNER_PUBLIC_KEY`             | Public Key        | Hetzner SSH deployment key (ed25519)                                                                                                                                                                                |
| `HETZNER_S3_ACCESS_KEY`          | Access Key ID     | Hetzner Object Storage project-level (all buckets)                                                                                                                                                                  |
| `HETZNER_S3_SECRET_KEY`          | Secret Access Key | Hetzner Object Storage project-level (all buckets)                                                                                                                                                                  |
| `HETZNER_ROOT_PASSWORD`          | Random password   | `token_urlsafe(32)` initial root access only                                                                                                                                                                        |
|                                  |                   |                                                                                                                                                                                                                     |
| **Storagebox**                   |                   |                                                                                                                                                                                                                     |
| `STORAGEBOX_HEARTH_PASSWORD`     | Password          | Sub-account password set on creation subaccount                                                                                                                                                                     |
| `STORAGEBOX_FORGE_PASSWORD`      | Password          | Sub-account password set on creation subaccount                                                                                                                                                                     |
|                                  |                   |                                                                                                                                                                                                                     |
| **Borg backup**                  |                   |                                                                                                                                                                                                                     |
| `BORG_PASSPHRASE_HEARTH`         | Passphrase        | `token_urlsafe(48)` — Used to encrypt/decrypt Borg backup archives                                                                                                                                                  |
| `BORG_PASSPHRASE_FORGE`          | Passphrase        | `token_urlsafe(48)` — Used to encrypt/decrypt Borg backup archives                                                                                                                                                  |
|                                  |                   |                                                                                                                                                                                                                     |
| **Terraform**                    |                   |                                                                                                                                                                                                                     |
| `TERRAFORM_API_TOKEN`            | API token         | Created in Terraform Cloud → User Settings → Tokens                                                                                                                                                                 |
|                                  |                   |                                                                                                                                                                                                                     |
| **Authentik**                    |                   |                                                                                                                                                                                                                     |
| `AUTHENTIK_EMAIL__USERNAME`      | Email             | See [infomaniak.md → SMTP Server Configuration](../services/infomaniak.md#smtp-server-configuration-for-authentik)                                                                                                  |
| `AUTHENTIK_EMAIL__PASSWORD`      | Password          | See [infomaniak.md → SMTP Server Configuration](../services/infomaniak.md#smtp-server-configuration-for-authentik)                                                                                                  |
| `AUTHENTIK_POSTGRESQL__PASSWORD` | Password          | `token_urlsafe(48)` — Used for Authentik PostgreSQL database (double underscore — matches Authentik's own env var convention)                                                                                       |
| `AUTHENTIK_SECRET_KEY`           | Secret Key        | `token_urlsafe(64)` — Used for Authentik session signing (86 chars)                                                                                                                                                 |
|                                  |                   |                                                                                                                                                                                                                     |
| **Portainer**                    |                   | No secrets — local admin auth by design (must stay reachable even if Authentik is down); see [hearth.md → Design decision](./hearth.md#design-decision--portainer-stays-on-local-auth-not-sso)                      |
|                                  |                   |                                                                                                                                                                                                                     |
| **Wud**                          |                   |                                                                                                                                                                                                                     |
| `WUD_SSO_CLIENT_SECRET`          | Secret            | Secret used for Wud SSO                                                                                                                                                                                             |
|                                  |                   |                                                                                                                                                                                                                     |
| **Vaultwarden**                  |                   |                                                                                                                                                                                                                     |
| `VAULTWARDEN_ADMIN_TOKEN`        | Token             | Raw admin token for Vaultwarden — strata auto-generates/stores this; used to log in to the admin panel                                                                                                              |
| `VAULTWARDEN_ADMIN_ARGON`        | Hash              | Argon2 hash of `VAULTWARDEN_ADMIN_TOKEN` — this is what Vaultwarden's `ADMIN_TOKEN` env var actually needs; precomputed once and stored directly (see [Secrets for Vaultwarden](#secrets-for-vaultwarden))          |
| `VAULTWARDEN_SSO_CLIENT_SECRET`  | Secret            | Secret used for Vaultwarden SSO                                                                                                                                                                                     |
|                                  |                   |                                                                                                                                                                                                                     |
| **Healthcheck**                  |                   |                                                                                                                                                                                                                     |
| `HEALTHCHECK_PING_BACKUP`        | URL               | Backup ping URL for Healthcheck                                                                                                                                                                                     |

### Generating Secrets

> Note. Strata can generate random secrets for you during provisioning. So no extra tools are needed.
> You do need to generate the secrets at least once and store them in Bitwarden and Infisical Cloud,

**Option 1 — Print a random value only (copy into Bitwarden/Infisical manually):**

```powershell
strata secret generate --length 64 --format urlsafe
strata secret generate --length 64 --format hex

# Or using Python's secrets module (available in all Python installations)
python -c "from secrets import token_urlsafe, token_hex; print('urlsafe(64):', token_urlsafe(64)); print('hex(32):', token_hex(32))"
```

**Option 2 — Generate and store in one step:**

For any secret declared in the environment YAML (`spec.secrets`) with an integration-backed store (`infisical`, `azure-keyvault`, `vault`, `bitwarden`) and a `generate:` spec, `strata secret put` creates the value and writes it directly to the store — no manual copy/paste needed:

```yaml
# config/env-haven-prd.yaml
spec:
  secrets:
    - key: AUTHENTIK_SECRET_KEY
      store: infisical
      value: AUTHENTIK_SECRET_KEY
      generate:
        type: urlsafe
        length: 64
```

```powershell
strata secret put AUTHENTIK_SECRET_KEY --generate -f config/env-haven-prd.yaml
```

`generate:` is only valid on integration-backed stores — not on `constant`/`environment`/`github`. Still store a copy of the generated value in Bitwarden as backup.

### Infisical Cloud Setup

> **ACTION:** Create a new project in Infisical Cloud for Haven. Store the project ID in Bitwarden and GitHub Variables.

See [Infisical Setup](../services/infisical.md#initial-setup) for instructions on creating a new project and configuring the GitHub integration.

**Create a machine identity in Infisical Cloud:**

1. [app.infisical.com](https://app.infisical.com) → Organization → Access Control → Machine Identities → Create
2. Name: `haven-github-actions`
3. Auth method: **Universal Auth**
4. Assign to your haven project with `read` role
5. Copy the **Client ID** and **Client Secret** → store in Bitwarden → add to GitHub Secrets

### Secrets for Hetzner API Token

> **ACTION:** Generate a Hetzner Cloud project token. Store it in Bitwarden and Infisical Cloud.

See [Hetzner Setup](../services/hetzner.md#initial-setup) for instructions on creating a new project and generating an API token.

### Secrets for Hetzner SSH Deployment Key

> **ACTION:** Generate an ed25519 SSH key pair. Store the public key in the Hetzner Cloud project and the private key in Bitwarden. Create Infisical secrets.

Create an ed25519 SSH key pair for deployment. The public key goes to Hetzner (for Terraform provisioning and BorgBackup), the private key goes to Infisical Cloud and Bitwarden. You can generate the key pair using PowerShell or any SSH key generation tool. Bitwarden also has a built-in SSH key generator that can create and store the key pair directly in your vault.

See [Hetzner Setup](../services/hetzner.md#create-a-hetzner-cloud-ssh-key-pair) for instructions on creating an SSH key pair and storing it in Bitwarden and Infisical Cloud.

```powershell
# Generate ed25519 SSH key pair
ssh-keygen -t ed25519 -C "haven-deploy" -f ~/.ssh/haven_ed25519 -N ""

# Public key → Hetzner Cloud project
Get-Content ~/.ssh/haven_ed25519.pub

# Private key → Infisical Cloud
Get-Content ~/.ssh/haven_ed25519 -Raw
```

### Secrets for Hetzner Storagebox

> **ACTION:** Create a Storage Box in Hetzner Robot and two sub-accounts (one per node). Store passwords in Bitwarden and Infisical Cloud.

See [Hetzner Setup](../services/hetzner.md#create-a-hetzner-cloud-storagebox) for the full explanation of creating a Storage Box and sub-accounts (BX11 order, external reachability, hostname pattern).

Sub-accounts are created in **Hetzner Robot** (not the Cloud Console) — one per node, each with its own password and hostname. These are externally-created values, so push them to Infisical Cloud via strata with `--value` (no `generate:` spec needed):

```yaml
# config/env-haven-prd.yaml
spec:
  secrets:
    - key: STORAGEBOX_HEARTH_PASSWORD
      store: infisical
    - key: STORAGEBOX_FORGE_PASSWORD
      store: infisical
```

```powershell
strata secret put STORAGEBOX_HEARTH_PASSWORD --value "<hearth-sub-account-password>" -f config/env-haven-prd.yaml
strata secret put STORAGEBOX_FORGE_PASSWORD --value "<forge-sub-account-password>" -f config/env-haven-prd.yaml
```

`STORAGEBOX_HOST`, `STORAGEBOX_SUBACCOUNT_HEARTH`, and `STORAGEBOX_SUBACCOUNT_FORGE` are non-secret hostnames/usernames — add them as GitHub Variables (see the table above), not as Infisical secrets or via `strata secret put`.

### Secrets for Hetzner S3 Storage

> **ACTION:** Generate an S3 access key pair in the Hetzner Cloud console. Store the Access Key ID and Secret Access Key in Bitwarden and Infisical Cloud.

See [Hetzner Setup](../services/hetzner.md#create-hetzner-cloud-s3-access-keys) for the full explanation of creating the access key pair and its project-wide scope.

Three buckets are provisioned by the `ansible-s3/forge-s3.yml` playbook using this one key pair:

- `haven-photos` — Immich external photo library
- `haven-media` — media overflow (large binary assets)
- `haven-docs` — family documents (games/manuals, general archive) — organized/browsed via Nextcloud, Kavita, Paperless-ngx

This is another externally-created value, so push it the same way — `--value`, no `generate:` spec:

```powershell
strata secret put HETZNER_S3_ACCESS_KEY --value "<access-key-id>" -f config/env-haven-prd.yaml
strata secret put HETZNER_S3_SECRET_KEY --value "<secret-access-key>" -f config/env-haven-prd.yaml
```

### Secrets for Terraform Cloud API Token

> **ACTION:** Generate a Terraform Cloud API token. Store it in Bitwarden and Infisical Cloud.

### Secrets for Healthcheck

> **ACTION:** Create a check in Healthchecks.io for backup monitoring. Store the ping URL in Bitwarden and Infisical Cloud.

1. [healthchecks.io](https://healthchecks.io) → New Check → name it `haven-backup`
2. Set the period to match the backup schedule (e.g. 24h) with a grace period (e.g. 1h)
3. Copy the **Ping URL** → store in Bitwarden and Infisical as `HEALTHCHECK_PING_BACKUP`

### Automated Secrets Generation

> **ACTION:** For each service that requires a random secret, declare the key in the environment YAML with a `generate:` spec. Strata will generate the value and write it directly to Infisical Cloud in one step.

Other services (Authentik, Wud, Vaultwarden) require random secrets for SSO and database access. These are generated automatically via `strata secret put --generate` and stored in Infisical Cloud. No manual steps are required. Strata will create the value and writes them directly to Infisical Cloud in one step (see [Generating Secrets](#generating-secrets) above for the mechanism). Portainer needs no secrets at all — it uses local admin auth by design, not SSO.

**Vaultwarden admin token is automated, hashing is a one-time manual step.** Strata auto-generates the **raw** token (`VAULTWARDEN_ADMIN_TOKEN`) like any other secret. Vaultwarden's container needs the **Argon2 hash** of that token in its own `ADMIN_TOKEN` env var, not the raw value — this hash is precomputed **once**, interactively, via [Cookbook: Storing a Hashed Secret Before Storage](../cookbooks/hash-secret-before-storage.md) (pipes the raw token through `docker run vaultwarden/server /vaultwarden hash --preset owasp`, `scripts/hash_argon2.py` automates that same transform) and stored directly as `VAULTWARDEN_ADMIN_ARGON`. `deploy-hearth-deploy.yml` fetches `VAULTWARDEN_ADMIN_ARGON` directly at deploy time — no hashing happens in the pipeline itself. Still copy the raw token from Infisical into Bitwarden once (you need it to log in and it isn't recoverable from the hash).

Every key in the **Infisical Secrets** table above that needs a random value is declared the same way: one entry per key, with a `generate:` spec on it. There's no separate list to maintain here; the table above is the single source of truth for which keys exist, and the environment YAML just adds the `generate:` block to each:

```yaml
# config/env-haven-prd.yaml
spec:
  secrets:
    - key: AUTHENTIK_SECRET_KEY
      store: infisical
      generate:
        type: urlsafe
        length: 64
    # ...repeat for every other key marked as generated in the table above
```

```powershell
strata secret put AUTHENTIK_SECRET_KEY --generate -f config/env-haven-prd.yaml
# ...repeat for each key declared with a generate: spec
```

Still store a copy of every generated value in Bitwarden as backup.

#### Secrets for Authentik

> **ACTION:** Generated automatically via `strata secret put --generate` (see above). No manual steps required.

#### Secrets for Portainer

> **ACTION:** None — Portainer uses local admin auth by design (must stay reachable even if Authentik is down). No secrets to generate. See [hearth.md → Design decision](./hearth.md#design-decision--portainer-stays-on-local-auth-not-sso).

#### Secrets for Wud

> **ACTION:** Generated automatically via `strata secret put --generate` (see above). No manual steps required.

#### Secrets for Vaultwarden

> **ACTION:** `VAULTWARDEN_SSO_CLIENT_SECRET` and `VAULTWARDEN_ADMIN_TOKEN` are generated automatically via `strata secret put --generate`. No manual steps required for generation.
>
> The **hash** that Vaultwarden's container actually needs (`VAULTWARDEN_ADMIN_ARGON`) is a one-time manual step, not part of any pipeline — run [Cookbook: Storing a Hashed Secret Before Storage](../cookbooks/hash-secret-before-storage.md) (or `scripts/hash_argon2.py`, which automates the same `docker run vaultwarden/server /vaultwarden hash` transform) once, interactively, and store the result directly as `VAULTWARDEN_ADMIN_ARGON`. `deploy-hearth-deploy.yml` fetches `VAULTWARDEN_ADMIN_ARGON` directly at deploy time via `strata values get` — it does not hash anything itself.
>
> Copy the raw token from Infisical into Bitwarden once (you need it to log in — it cannot be recovered from the hash).
