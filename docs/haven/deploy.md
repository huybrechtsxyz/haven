# Haven — Deployment Runbook

> Full reference: [Phase guides](README.md) | Repo: `huybrechtsxyz/haven`

Single-page procedure to deploy Haven from scratch. Follow in order.

---

## 1. Prerequisites

> Full details: [phase-0-prerequisites.md](phase-0-prerequisites.md)

**Tools** (install on workstation):

```powershell
pip install xyz-strata==0.0.9 ansible-core
winget install GitHub.cli Git.Git
# OpenTofu: choco install opentofu  OR  https://opentofu.org/docs/intro/install/
```

**External accounts required:** Hetzner Cloud, Hetzner Robot, Terraform Cloud, GitHub, INWX.

**SSH deploy key:**

```powershell
ssh-keygen -t ed25519 -C "haven-deploy" -f ~/.ssh/haven_ed25519 -N ""
```

**Generate all secrets** (run once, save every value to Vaultwarden):

```powershell
# Authentik secret key
python -c "import secrets; print(secrets.token_urlsafe(64))"
# Authentik PostgreSQL password
python -c "import secrets; print(secrets.token_urlsafe(32))"
# Vaultwarden admin token
python -c "import secrets; print(secrets.token_urlsafe(48))"
# Infisical auth secret (must be exactly 64 hex chars)
python -c "import secrets; print(secrets.token_hex(32))"
# Infisical encryption key (must be exactly 32 chars)
python -c "import secrets; print(secrets.token_hex(16))"
# Infisical PostgreSQL password
python -c "import secrets; print(secrets.token_urlsafe(32))"
# BorgBackup passphrase
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

**Terraform Cloud:** create org `huybrechts-xyz`, workspace `haven_deploy_prd`, execution mode **Local**.

**GitHub Secrets** — repo → Settings → Secrets → Environments → `production`:

| Secret                          | Notes                                            |
| ------------------------------- | ------------------------------------------------ |
| `TERRAFORM_API_TOKEN`           | Terraform Cloud token                            |
| `HETZNER_API_TOKEN`             | Hetzner Cloud project token (read/write)         |
| `HETZNER_PUBLIC_KEY`            | Contents of `~/.ssh/haven_ed25519.pub`           |
| `HETZNER_PRIVATE_KEY`           | Contents of `~/.ssh/haven_ed25519`               |
| `HETZNER_ROOT_PASSWORD`         | Strong random password                           |
| `AUTHENTIK_SECRET_KEY`          | From generate step above                         |
| `AUTHENTIK_POSTGRESQL_PASSWORD` | From generate step above                         |
| `VAULTWARDEN_ADMIN_TOKEN`       | From generate step above                         |
| `INFISICAL_AUTH_SECRET`         | 64 hex chars (`token_hex(32)`)                   |
| `INFISICAL_ENCRYPTION_KEY`      | **32 chars exactly** (`token_hex(16)`) — not 64! |
| `INFISICAL_POSTGRESQL_PASSWORD` | From generate step above                         |
| `BORG_PASSPHRASE`               | From generate step above                         |

---

## 2. DNS

> Full details: [phase-1-dns-domain.md](phase-1-dns-domain.md)

In INWX → `huybrechts.xyz` → DNS, add these A records (after you have the server IP from Step 3):

| Name                     | Value         | TTL |
| ------------------------ | ------------- | --- |
| `huybrechts.xyz`         | `91.98.78.36` | 300 |
| `auth.huybrechts.xyz`    | `91.98.78.36` | 300 |
| `vault.huybrechts.xyz`   | `91.98.78.36` | 300 |
| `secrets.huybrechts.xyz` | `91.98.78.36` | 300 |

> ⚠️ **Do NOT enable DNSSEC at INWX.** It creates a broken DNSSEC chain that causes `SERVFAIL` from validating resolvers → Caddy ACME challenges fail → no TLS certificates.

---

## 3. Infrastructure

> Full details: [phase-2-infrastructure.md](phase-2-infrastructure.md)

**Order Hetzner Storage Box** (manual — no API exists):
[robot.hetzner.com](https://robot.hetzner.com) → Storage Boxes → Order BX11 (1 TB, NBG1).
Create sub-account `hearth_backup` with SSH access enabled.
Note the hostname (e.g. `u604953.your-storagebox.de`).

**Set storagebox hostname** in `deploy/ansible-config/vars/main.yml`:

```yaml
storagebox_host: "u604953.your-storagebox.de"
```

Commit and push.

**Run the pipeline** — GitHub Actions → `Deploy - haven` → Run workflow:

| Input        | Value   |
| ------------ | ------- |
| `run_init`   | `false` |
| `run_config` | `false` |
| `run_deploy` | `false` |

This runs `strata build` + Terraform to provision the VPS, firewall, and network.
Note the server public IP from the Terraform outputs.

---

## 4. Server initialisation

> Full details: [phase-3-hearth-init.md](phase-3-hearth-init.md)

Run the pipeline:

| Input            | Value   |
| ---------------- | ------- |
| `run_init`       | `true`  |
| `configure_borg` | `false` |
| `run_config`     | `false` |
| `run_deploy`     | `false` |

Installs Docker, creates `haven` user, directory tree, hardens SSH.

---

## 5. Deploy services

> Full details: [phase-4-hearth-deploy.md](phase-4-hearth-deploy.md)

Run the pipeline:

| Input        | Value   |
| ------------ | ------- |
| `run_init`   | `false` |
| `run_config` | `true`  |
| `run_deploy` | `true`  |

`hearth-config` enforces system config; `hearth-deploy` writes the Docker Compose stack and starts all 9 containers. Caddy obtains Let's Encrypt certificates automatically on first start (~30 seconds).

**Verify:**
- `https://auth.huybrechts.xyz` — Authentik login page
- `https://vault.huybrechts.xyz` — Vaultwarden login page
- `https://secrets.huybrechts.xyz` — Infisical login page

---

## 6. Service first-run setup

> Full details: [phase-5-service-setup.md](phase-5-service-setup.md)

**Authentik** — create admin account (available once only):
`https://auth.huybrechts.xyz/if/flow/initial-setup/`

**Vaultwarden** — enable registration, create accounts, disable registration:
1. `https://vault.huybrechts.xyz/admin` → enter `VAULTWARDEN_ADMIN_TOKEN`
2. General Settings → Allow new signups → **enable** → Save
3. `https://vault.huybrechts.xyz/#/register` → create each user account
4. Admin panel → Allow new signups → **disable** → Save

**Infisical** — create admin account:
`https://secrets.huybrechts.xyz` → Sign Up

---

## 7. Backups (BorgBackup)

> Full details: [phase-6-backups.md](phase-6-backups.md)

### Step A — Generate SSH key

Run pipeline:

| Input            | Value   |
| ---------------- | ------- |
| `run_init`       | `true`  |
| `configure_borg` | `false` |
| `run_config`     | `false` |
| `run_deploy`     | `false` |

In the workflow log → task **"Display borg SSH public key"** → copy the `ssh-ed25519 ...` line.

### Step B — Authorise SSH key *(manual — Hetzner Robot only)*

[robot.hetzner.com](https://robot.hetzner.com) → Storage Boxes → `u604953` → Sub-accounts → `hearth_backup` → SSH Keys → paste the key → Save.

### Step C — Initialise Borg repository

Run pipeline:

| Input            | Value   |
| ---------------- | ------- |
| `run_init`       | `true`  |
| `configure_borg` | `true`  |
| `run_config`     | `false` |
| `run_deploy`     | `false` |

In the workflow log → task **"Display borg repo key"** → copy and save to Vaultwarden as **"Haven BorgBackup repo key"**.

### Step D — Enable automated backups

In `deploy/ansible-config/vars/main.yml`:

```yaml
configure_borg: true
```

Commit and push, then run pipeline with `run_config: true`. The backup script and daily 02:00 UTC cron job are now active.

---

## Done ✓

| Service     | URL                              |
| ----------- | -------------------------------- |
| Authentik   | `https://auth.huybrechts.xyz`    |
| Vaultwarden | `https://vault.huybrechts.xyz`   |
| Infisical   | `https://secrets.huybrechts.xyz` |

Daily backups run at 02:00 UTC to `u604953.your-storagebox.de:./hearth`.  
Log: `/var/log/haven-backup.log`
> **Subsequent deploys:** use `backup_before_deploy: true` to snapshot before changes. Use `dry_run: true` on any run for a plan-only check.