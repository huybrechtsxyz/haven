# Phase 0 — Prerequisites

> [← Overview](README.md) | [Next: Phase 1 — DNS →](phase-1-dns-domain.md)

Everything you need before running a single command.

---

## Tools

Install these on your workstation:

| Tool       | Version | Install                                                                              |
| ---------- | ------- | ------------------------------------------------------------------------------------ |
| `strata`   | ≥ 0.0.9 | `pip install xyz-strata==0.0.9`                                                      |
| OpenTofu   | ≥ 1.6   | `choco install opentofu` or [opentofu.org](https://opentofu.org/docs/intro/install/) |
| Ansible    | ≥ 2.14  | `pip install ansible-core`                                                           |
| GitHub CLI | latest  | `winget install GitHub.cli`                                                          |
| Git        | latest  | `winget install Git.Git`                                                             |

Verify:

```powershell
strata --version
tofu --version
ansible --version
gh --version
```

---

## External accounts

| Service         | Purpose                    | URL                                                    |
| --------------- | -------------------------- | ------------------------------------------------------ |
| Hetzner Cloud   | VPS hosting                | [console.hetzner.cloud](https://console.hetzner.cloud) |
| Hetzner Robot   | Storage Box (manual order) | [robot.hetzner.com](https://robot.hetzner.com)         |
| Terraform Cloud | Remote state storage       | [app.terraform.io](https://app.terraform.io)           |
| GitHub          | Repo + CI/CD               | [github.com](https://github.com)                       |
| INWX            | DNS / domain registrar     | [my.inwx.de](https://my.inwx.de)                       |

---

## SSH key pair

Generate a dedicated deploy key (or create one in Bitwarden):

```powershell
ssh-keygen -t ed25519 -C "haven-deploy" -f ~/.ssh/haven_ed25519 -N ""
```

You need both values for the next steps:

```powershell
# Public key — goes to Hetzner
Get-Content ~/.ssh/haven_ed25519.pub

# Private key — goes to GitHub Secrets
Get-Content ~/.ssh/haven_ed25519 -Raw
```

---

## Generate service secrets

Run these once and store each value in a password manager (Bitwarden / Vaultwarden).

```powershell
# Authentik secret key — 50+ random chars
python -c "import secrets; print(secrets.token_urlsafe(64))"

# Authentik PostgreSQL password
python -c "import secrets; print(secrets.token_urlsafe(32))"

# Vaultwarden admin token
python -c "import secrets; print(secrets.token_urlsafe(48))"

# Infisical auth secret — MUST be exactly 64 hex chars (32 bytes)
# On Linux/macOS:  openssl rand -hex 32
# On Windows:
python -c "import secrets; print(secrets.token_hex(32))"

# Infisical encryption key — MUST be exactly 32 chars (AES-256-GCM key)
# On Linux/macOS:  openssl rand -hex 16
# On Windows:
python -c "import secrets; print(secrets.token_hex(16))"

# Infisical PostgreSQL password
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

> **Critical:** `INFISICAL_ENCRYPTION_KEY` must be **exactly 32 characters**. Using 64 chars causes Infisical to crash at startup with "Invalid key length". Use `token_hex(16)` (16 bytes = 32 hex chars).

---

## Terraform Cloud setup

1. Create organization: `huybrechts-xyz`
2. Create workspace: `haven_deploy_prd` (must match exactly)
3. Set execution mode → **Local** (TF Cloud stores state; your CI drives runs)
4. Generate an API token: User Settings → Tokens → Create token
5. Save as `TERRAFORM_API_TOKEN` in GitHub Secrets (next section)

---

## GitHub Secrets

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**.

Create an **environment** named `production` and add these secrets to it:

| Secret name                     | Value                           | Notes                                                             |
| ------------------------------- | ------------------------------- | ----------------------------------------------------------------- |
| `TERRAFORM_API_TOKEN`           | Terraform Cloud API token       |                                                                   |
| `HETZNER_API_TOKEN`             | Hetzner Cloud project API token | Read/write                                                        |
| `HETZNER_PUBLIC_KEY`            | SSH public key (`.pub` content) | Single line                                                       |
| `HETZNER_PRIVATE_KEY`           | SSH private key (full content)  | Including headers                                                 |
| `HETZNER_ROOT_PASSWORD`         | Strong random password          | Used only for initial Terraform provisioning                      |
| `AUTHENTIK_SECRET_KEY`          | 50+ char random string          | From generate step above                                          |
| `AUTHENTIK_POSTGRESQL_PASSWORD` | Random password                 | From generate step above                                          |
| `VAULTWARDEN_ADMIN_TOKEN`       | Random token                    | From generate step above                                          |
| `INFISICAL_AUTH_SECRET`         | 64 hex chars exactly            | `token_hex(32)`                                                   |
| `INFISICAL_ENCRYPTION_KEY`      | **32 chars exactly**            | `token_hex(16)` — not 64!                                         |
| `INFISICAL_POSTGRESQL_PASSWORD` | Random password                 | From generate step above                                          |
| `BORG_PASSPHRASE`               | Strong random passphrase        | See [Phase 6](phase-6-backups.md) — add when ordering Storage Box |

> **Note:** The workflow uses `environment: production` on the deploy job. Secrets must be in the `production` environment, not just repository-level secrets, or the job won't see them.

---

## Checklist

- [ ] All tools installed and version-verified
- [ ] SSH key pair generated
- [ ] All 6 service secrets generated and stored in password manager
- [ ] Terraform Cloud organization + workspace created (Local execution mode)
- [ ] GitHub `production` environment created
- [ ] All 11 GitHub Secrets added with correct names and values (+ `BORG_PASSPHRASE` when ready)
- [ ] `strata` can see the haven repo config: `strata build list`
