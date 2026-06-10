

## Infrastructure Setup

### Hetzner Storage Box (manual — no API)

1. [robot.hetzner.com](https://robot.hetzner.com) → Storage Boxes → Order **BX11** (1 TB, Nuremberg)
2. Once activated, create sub-account (e.g. `u604953-sub1`), set a password, enable SSH access
3. Enable **External reachability** on both the main Storage Box and the sub-account
4. Note the hostname (e.g. `u604953.your-storagebox.de`) and sub-account username
5. Save the sub-account password in Vaultwarden and add it as GitHub Secret `HETZNER_STORAGEBOX_PASSWORD`
6. Add GitHub Environment Variables: `STORAGEBOX_HOST` and `STORAGEBOX_SUBACCOUNT`
7. Commit and push

> ⚠️ **External reachability must be enabled** — without it, only Hetzner-internal traffic can reach port 23. The VPS connects via its public IP, so BorgBackup will time out if this is off.

### Provision VPS (pipeline)

GitHub Actions → `Deploy - haven` → Run workflow:

| Input        | Value   |
| ------------ | ------- |
| `run_init`   | `false` |
| `run_config` | `false` |
| `run_deploy` | `false` |

This runs `strata build` + Terraform to provision the VPS, firewall, and network.
Note the **server IP** from the Terraform output — you need it for the DNS A records above.

### DNS A records

Once you have the server IP, add the A records listed in [DNS Haven records](#dns-haven-records-huybrechtsxyz) at INWX.

### DNS Haven records (huybrechts.xyz)

| Name                       | Type | Value                         | TTL  | Purpose                    |
| -------------------------- | ---- | ----------------------------- | ---- | -------------------------- |
| `huybrechts.xyz`           | A    | `<server-ip-address>`         | 3600 | Root domain → Hearth VPS   |
| `auth.huybrechts.xyz`      | A    | `<server-ip-address>`         | 3600 | Authentik (SSO)            |
| `vault.huybrechts.xyz`     | A    | `<server-ip-address>`         | 3600 | Vaultwarden (passwords)    |
| `secrets.huybrechts.xyz`   | A    | `<server-ip-address>`         | 3600 | Infisical (secrets)        |
| `portainer.huybrechts.xyz` | A    | `<server-ip-address>`         | 3600 | Portainer (container UI)   |
| `wud.huybrechts.xyz`       | A    | `<server-ip-address>`         | 3600 | WUD (update notifications) |
| `huybrechts.xyz`           | CAA  | `128 issue "letsencrypt.org"` | 3600 | Allow Let's Encrypt only   |

## Initializing Hearth

Bootstrap the server with Docker, the `haven` service user, directory structure, and SSH hardening.

**Playbook:** `deploy/ansible-init/hearth-init.yml`  
**Runs once** on a fresh server. Safe to re-run — all tasks are idempotent.

### What hearth-init does

| Task                    | Details                                                               |
| ----------------------- | --------------------------------------------------------------------- |
| Set timezone            | `Europe/Brussels`                                                     |
| Install packages        | `curl`, `ca-certificates`, `gnupg`, `ufw`, `fail2ban`                 |
| Install Docker          | Official Docker CE repository, pinned version                         |
| Create `haven` user     | System user, home `/opt/haven`, member of `docker` group              |
| Create directory tree   | `/opt/haven/etc`, `/opt/haven/var/data`, `/opt/haven/var/certs`, etc. |
| Generate BorgBackup key | `borg_ed25519` SSH key pair in `/opt/haven/.ssh/`                     |
| SSH hardening           | `PermitRootLogin no`, `PasswordAuthentication no`, key-only auth      |

### Directory structure created

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

### Run hearth-init

GitHub Actions → `Deploy - haven` → Run workflow:

| Input            | Value   |
| ---------------- | ------- |
| `run_init`       | `true`  |
| `configure_borg` | `false` |
| `run_config`     | `false` |
| `run_deploy`     | `false` |

After the run completes, check the workflow log for the task **"Display borg SSH public key"** — you'll need this key later for BorgBackup setup.

> **Note:** After init completes, SSH root login is disabled. All subsequent access is via the deploy key through the pipeline.

## Configuring Hearth

Enforce system configuration on every deploy. Corrects drift without re-installing software.

**Playbook:** `deploy/ansible-config/hearth-config.yml`  
**Runs on every deploy.** Safe to re-run — all tasks are idempotent.

### What hearth-config does

| Task                       | Details                                                                        |
| -------------------------- | ------------------------------------------------------------------------------ |
| Stop competing web servers | Disables `apache2` and `nginx` if present (frees ports 80/443)                 |
| Security updates           | `apt upgrade safe`, removes unused packages                                    |
| Install packages           | `borgbackup`, `htop`, `ncdu`, `fail2ban`, `jq`, `unattended-upgrades`          |
| Timezone                   | Enforces `Europe/Brussels`                                                     |
| Unattended upgrades        | Security-only, no auto-reboot                                                  |
| Docker                     | Ensures Docker service is running and enabled                                  |
| Haven user                 | Ensures `haven` user/group, `docker` group membership                          |
| Directory structure        | Enforces ownership and permissions on `/opt/haven/` tree                       |
| fail2ban                   | Ensures running and enabled                                                    |
| SSH hardening              | Password auth disabled, root key-only (`prohibit-password`)                    |
| BorgBackup (conditional)   | Deploys backup script, passphrase file, cron job (when `configure_borg: true`) |

### Run hearth-config

GitHub Actions → `Deploy - haven` → Run workflow:

| Input        | Value   |
| ------------ | ------- |
| `run_config` | `true`  |
| `run_deploy` | `false` |

> On first deploy, run config and deploy together (`run_config: true`, `run_deploy: true`) to set up the system and start all containers in one pipeline run.

## Deploying Hearth

Deploy the Docker Compose stack with all 9 containers to the server.

**Playbook:** `deploy/ansible-deploy/hearth-deploy.yml`  
**Runs on every deploy.** Safe to re-run — pulls latest images and recreates changed containers.

### What hearth-deploy does

| Task                       | Details                                                            |
| -------------------------- | ------------------------------------------------------------------ |
| Create service directories | Config dirs, data dirs, correct ownership (uid 1000 for Authentik) |
| Sync build artifacts       | Copies `docker-compose.yml` and `Caddyfile` to `/opt/haven/etc/`   |
| Write `.env` file          | Injects service secrets (never committed to repo, `mode 0600`)     |
| Clean up old stacks        | Stops any lingering compose projects, releases ports 80/443        |
| Pull images                | `docker compose pull` — fetches latest images for all 9 services   |
| Start services             | `docker compose up -d --remove-orphans` (project name: `haven`)    |
| Restart Authentik          | Ensures server + worker pick up correct `/media` ownership         |
| Restart Caddy              | Only when Caddyfile changed or no valid Let's Encrypt certs found  |
| Diagnostics                | Waits 60s, then displays all container states + logs for debugging |

### Services deployed (9 containers)

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

### Run hearth-deploy

GitHub Actions → `Deploy - haven` → Run workflow:

| Input        | Value  |
| ------------ | ------ |
| `run_config` | `true` |
| `run_deploy` | `true` |

> Always run config before deploy — it ensures system packages, Docker, and directory permissions are correct before the compose stack starts.

Caddy obtains Let's Encrypt certificates automatically on first start (~30 seconds). The playbook waits 60 seconds then displays container states for verification.

### Verification

```powershell
# All must return 91.98.78.36
foreach ($h in @("huybrechts.xyz","auth.huybrechts.xyz","vault.huybrechts.xyz","secrets.huybrechts.xyz","portainer.huybrechts.xyz","wud.huybrechts.xyz")) {
    Resolve-DnsName $h -Type A | Select-Object Name, IPAddress
}

# DNSSEC must NOT be active (expect SOA, not DS)
Resolve-DnsName -Name huybrechts.xyz -Type DS -Server "x.nic.xyz"
```

### Verify services

All must show a login page:

- `https://auth.huybrechts.xyz` — Authentik
- `https://vault.huybrechts.xyz` — Vaultwarden
- `https://secrets.huybrechts.xyz` — Infisical
- `https://portainer.huybrechts.xyz` — Portainer
- `https://wud.huybrechts.xyz` — WUD (What's Up Docker)

## Service Initial Setup

> Detailed configuration instructions: [AUTHENTIK.md](AUTHENTIK.md)

### Authentik

Authentik is a SSO / identity provider. It requires a one-time initial setup to create the first admin account and configure basic settings.

1. `https://auth.huybrechts.xyz/if/flow/initial-setup/`
2. Create admin account (email + password)
3. Store credentials in Vaultwarden
4. Follow the full setup guide in [AUTHENTIK.md](AUTHENTIK.md) for:
   - SMTP email configuration
   - Creating family user accounts
   - OIDC app setup for Vaultwarden and Infisical
5. Test login at `https://auth.huybrechts.xyz/if/core/login/`

> **Note:**
> - Authentik must be set up before Vaultwarden and Infisical, since they rely on Authentik for authentication.
> - Do not use your personal email for the admin account. Create a dedicated email address (e.g. `admin@huybrechts.xyz`) and set up forwarding to your personal email.

### Authentik — Assign users to groups (required for SSO access)

The blueprint creates three groups automatically (`admins`, `parents`, `members`) and all SSO applications are gated by group policy. **No user can log in to any SSO application until they are assigned to at least one group.** This includes `akadmin`.

Assign group membership after every new user is created:

| User                              | Group     | Access          |
| --------------------------------- | --------- | --------------- |
| `akadmin` (or your admin account) | `admins`  | All apps        |
| Adult family members              | `parents` | All family apps |
| Other family members              | `members` | Shared apps     |

**Steps:**

1. Admin Interface → Directory → Groups → select the group
2. Users tab → Add existing user → select the user → Add
3. Repeat for each user

> ⚠️ If this step is skipped, SSO logins will fail with **"Permission denied — Policy binding returned result False"**. The user is authenticated but not authorised.

### Vaultwarden

Vaultwarden is a password manager. After Authentik is set up, you can create the first admin account in Vaultwarden and log in to the web vault.

> ⚠️ **Admin token:** The `VAULTWARDEN_ADMIN_TOKEN` GitHub Secret must be the Argon2 hash, not the plain-text token. You always log in with the **plain-text** token — Vaultwarden verifies it against the hash internally. If the secret is plain text, Vaultwarden logs a warning on every startup.

1. `https://vault.huybrechts.xyz/admin` → enter the **plain-text** `VAULTWARDEN_ADMIN_TOKEN`
2. General Settings → Allow new signups → **enable** → Save
3. `https://vault.huybrechts.xyz/#/register` → create user accounts
4. Admin panel → Allow new signups → **disable** → Save 
5. Test login at `https://vault.huybrechts.xyz/#/login`
6. Configure email (SMTP) for password reset notifications
7. Test password reset flow
8. Configure Authentik as SSO provider
   - Admin panel → Single Sign-On → Add provider → OpenID Connect
   - Provider URL: `https://auth.huybrechts.xyz/if/realms/master/protocol/openid-connect`
   - Client ID: `vaultwarden`
   - Save, then test SSO login

### Infisical

Infisical is a secrets management platform used by admins to manage application secrets.

1. `https://secrets.huybrechts.xyz` → Sign Up → create the first admin account (email + password)
2. Store credentials in Vaultwarden under "Infisical Admin"
3. Complete the onboarding wizard (create an organisation and a first project)

> **No SSO** — Infisical OIDC SSO requires the Pro plan (paid). Login with email + password only. This is acceptable since Infisical is an admin-only tool.

**Enable MFA (TOTP):**

4. Log in to `https://secrets.huybrechts.xyz`
5. Top-right avatar → Personal Settings → Security → Two-Factor Authentication → Enable
6. Scan the QR code with an authenticator app (e.g. Vaultwarden TOTP, Aegis, or Authy)
7. Enter the verification code to confirm → Save
8. Store the backup codes in Vaultwarden under "Infisical Admin — MFA backup codes"

> MFA is per-user and opt-in. For an admin-only tool with no SSO, enabling TOTP is strongly recommended.

### Portainer

Portainer CE is the container management UI. Login with username + password only.

1. Log in to `https://portainer.huybrechts.xyz` with the admin credentials set during initial setup
2. Store credentials in Vaultwarden under "Portainer Admin"

> **No SSO** — Portainer CE does not support OAuth/OIDC. That feature requires Portainer Business Edition (BE). The free BE tier covers up to 3 nodes and 5 users — upgrade later via Settings → Licenses if SSO becomes a priority.
>
> When upgrading to BE, the Authentik OAuth config to use is:
> - Authorization URL: `https://auth.huybrechts.xyz/application/o/authorize/`
> - Access Token URL: `https://auth.huybrechts.xyz/application/o/token/`
> - Resource URL: `https://auth.huybrechts.xyz/application/o/userinfo/`
> - Client ID: `portainer` — add this provider back to the blueprint and run `run_config=true`

## Configure BorgBackup

BorgBackup backs up critical data to the Hetzner Storage Box with `repokey-blake2` encryption, daily at 02:00 UTC.

- **Target:** `<STORAGEBOX_SUBACCOUNT>@<STORAGEBOX_HOST>:./hearth` (SSH port 23)
- **Data:** Authentik, Vaultwarden, Infisical volumes + `/opt/haven/etc`
- **Retention:** 7 daily, 4 weekly, 6 monthly
- **Log:** `/var/log/haven-backup.log`

### Step 1 — Generate SSH key and initialise repository

Add the `HETZNER_STORAGEBOX_PASSWORD` secret (the sub-account password from Hetzner Robot) to GitHub Environment Secrets.

Run pipeline with `run_init: true`, `configure_borg: true`, `run_config: false`, `run_deploy: false`.

The pipeline will automatically:

1. Generate an ed25519 SSH key pair on the VPS (`/opt/haven/.ssh/borg_ed25519`)
2. Upload the public key to the Storage Box using Hetzner's `install-ssh-key` command (requires `STORAGEBOX_PASSWORD`)
3. Scan the Storage Box host key and add it to `known_hosts`
4. Initialise the BorgBackup repository with `repokey-blake2` encryption
5. Export and display the repository key

> **How SSH key upload works:** Hetzner Storage Boxes require SSH keys to be uploaded via the `install-ssh-key` SSH command — the Robot web UI does not support this for port 23 access. The pipeline automates this using `sshpass` with the sub-account password. See [Hetzner docs: Add SSH keys](https://docs.hetzner.com/storage/storage-box/backup-space-ssh-keys/) for details.

### Step 2 — Save the repository key

In the workflow log → task **"Show BorgBackup repokey"** → copy the key block and save to Vaultwarden as **"Haven BorgBackup repo key"**.

> ⚠️ Without this key + the passphrase, backups **cannot** be restored.
>
> The repokey is also displayed on every `run_config` run (when `configure_borg: true`), so you can retrieve it later without re-running init.

### Step 3 — Enable automated backups

In `deploy/ansible-config/vars/main.yml`:

```yaml
configure_borg: true
```

Commit and push, then run pipeline with `run_config: true`. The backup script and daily cron job are now active.

## Subsequent Deploys

For routine updates (code changes, image updates):

| Input                  | Value  | Notes                                           |
| ---------------------- | ------ | ----------------------------------------------- |
| `run_config`           | `true` | Enforce system config, correct any drift        |
| `run_deploy`           | `true` | Pull latest images, recreate changed containers |
| `backup_before_deploy` | `true` | Optional — snapshot data before deploying       |
| `dry_run`              | `true` | Optional — plan only, no changes applied        |

## Monitoring

### Healthchecks.io

Healthchecks.io monitors **cron job execution** — it alerts when a scheduled task (like BorgBackup) fails to check in on time.

1. Sign up at <https://healthchecks.io>
2. Create a project named `haven`
3. Create checks:

| Check name      | Period   | Grace  | Purpose                           |
| --------------- | -------- | ------ | --------------------------------- |
| `hearth-backup` | 24 hours | 1 hour | BorgBackup daily cron (02:00 UTC) |

4. Copy the ping URL (e.g. `https://hc-ping.com/<uuid>`)
5. Add it as GitHub Environment Variable `HEALTHCHECK_PING_URL_BACKUP`
6. Run pipeline with `run_config: true` to deploy the updated backup script
7. Configure alert integrations (email, Telegram, or Pushover)
8. Store credentials in Vaultwarden

> Healthchecks.io is for **dead man's switch** monitoring — it alerts on *absence* of activity. If the backup cron doesn't ping within 25 hours, you get an alert.

### UptimeRobot

UptimeRobot monitors **service availability** — it alerts when a URL returns errors or becomes unreachable.

1. Sign up at <https://uptimerobot.com>
2. Add HTTPS monitors (keyword check for 200 OK):

| Monitor name | URL                                | Interval | Keyword         |
| ------------ | ---------------------------------- | -------- | --------------- |
| Authentik    | `https://auth.huybrechts.xyz`      | 5 min    | _(none needed)_ |
| Vaultwarden  | `https://vault.huybrechts.xyz`     | 5 min    | _(none needed)_ |
| Infisical    | `https://secrets.huybrechts.xyz`   | 5 min    | _(none needed)_ |
| Portainer    | `https://portainer.huybrechts.xyz` | 5 min    | _(none needed)_ |
| WUD          | `https://wud.huybrechts.xyz`       | 5 min    | _(none needed)_ |

3. Configure alert contacts (email + optional Telegram/Pushover)
4. Optional: create a public status page (paid feature):
   - UptimeRobot → My Settings → Public Status Pages → New Status Page
   - Add all three monitors
   - Custom domain: `status.huybrechts.xyz`
   - Add CNAME record at INWX:
     ```
     status.huybrechts.xyz  CNAME  stats.uptimerobot.com  3600
     ```
5. Store credentials in Vaultwarden

> UptimeRobot free tier gives 50 monitors at 5-minute intervals — more than enough for haven.

## Email (future)

### Infomaniak

1. Sign up at <https://manager.infomaniak.com>
2. Order kSuite (or Mail Service) for `huybrechts.xyz`
3. This is a future Wave 2 migration target — no configuration needed now
4. Store credentials in Vaultwarden

### DNS Email records

| Name                               | Type | Priority | Value                                 | TTL   |
| ---------------------------------- | ---- | -------- | ------------------------------------- | ----- |
| `huybrechts.xyz`                   | MX   | 1        | `ASPMX.L.GOOGLE.COM`                  | 14400 |
| `huybrechts.xyz`                   | MX   | 5        | `ALT1.ASPMX.L.GOOGLE.COM`             | 14400 |
| `huybrechts.xyz`                   | MX   | 5        | `ALT2.ASPMX.L.GOOGLE.COM`             | 14400 |
| `huybrechts.xyz`                   | MX   | 10       | `ALT3.ASPMX.L.GOOGLE.COM`             | 14400 |
| `huybrechts.xyz`                   | MX   | 10       | `ALT4.ASPMX.L.GOOGLE.COM`             | 14400 |
| `huybrechts.xyz`                   | TXT  |          | `v=spf1 include:_spf.google.com ~all` | 14400 |
| `google._domainkey.huybrechts.xyz` | TXT  |          | `v=DKIM1; k=rsa; p=MIIBIjAN...`       | 14400 |
