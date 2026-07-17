# Haven Hearth Setup

[← Back to Guide](./guide.md)

Hearth is the core VPS. It runs as a Docker Compose stack on a Hetzner CX23. Deployment happens in **two phases** — first a minimal foundation (Caddy + Infisical only), then the full stack once secrets are in Infisical.

> **Prerequisites:** `deploy-infra.yml` must have run successfully (VPS exists), DNS A records must be configured at INWX, and all Phase 1 GitHub Secrets must be set (see [guide-setup.md](./guide-setup.md)).

---

## Phase 1 — Foundation (Caddy + Infisical)

Deploy only the minimum required to bootstrap secrets management. No Authentik, no Vaultwarden, no family services yet.

**What gets deployed:**
- **Caddy** — reverse proxy + automatic TLS via Let’s Encrypt
- **Infisical** — secrets manager (PostgreSQL backend)

**Steps:**
1. Trigger `deploy-hearth.yml` with `mode: bootstrap`
2. Verify Caddy is serving TLS: `https://secrets.{domain}` should respond (Infisical login page)
3. Log in to Infisical admin UI: `https://secrets.{domain}`
   - Complete first-run setup wizard
   - Create project `haven`
   - Create environment: `prd`
4. Create a **Machine Identity** in Infisical for CI access:
   - Infisical → Admin → Machine Identities → Create
   - Auth Method: **Universal Auth**
   - Copy the **Client ID** and **Client Secret**
   - Grant the identity access to the `haven` project (`prd` environment, read scope)
5. Store machine identity credentials as GitHub Secrets:
   - `INFISICAL_CLIENT_ID` — the client ID from step 4
   - `INFISICAL_CLIENT_SECRET` — the client secret from step 4
6. Store the Infisical project ID as a GitHub Variable:
   - `INFISICAL_PROJECT_ID` — the project UUID (visible in Infisical project settings)
7. Populate application secrets in Infisical `haven/prd`:
   - **Strata-generated** (Phase 2): Authentik, Vaultwarden, WUD, and BorgBackup secrets
     > Strata will auto-generate these secrets if they don't already exist. You can manually create them yourself in Infisical first — Strata will not overwrite existing secrets.
   - **Manual-only**: Storage Box password, Healthchecks.io URL, SMTP credentials
   - See [guide-setup.md → Infisical Secrets](./guide-setup.md#infisical-secrets-fetched-at-runtime) for full details

**Verification checklist:**
- [ ] `https://secrets.{domain}` — Infisical login page loads with valid TLS
- [ ] Infisical admin account created
- [ ] `haven/prd` project and environment created in Infisical
- [ ] Machine Identity created and GitHub Secrets/Variables configured
- [ ] All application secrets populated in Infisical

---

## Phase 2 — Full Stack

Deploy the remaining Hearth services. All secrets are now in Infisical — the workflow fetches them at runtime via machine identity.

**What gets deployed:**
- **Authentik** — SSO / OIDC identity provider
- **Vaultwarden** — password manager
- **Portainer** — container management UI
- **WUD** — container update notifier

**Steps:**

1. Trigger `deploy-hearth.yml` with `mode: setup`
2. Workflow fetches secrets from Infisical, then deploys all services via Docker Compose
3. Complete post-deploy configuration for each service:

| Service     | Post-deploy steps                                      | Guide                                              |
| ----------- | ------------------------------------------------------ | -------------------------------------------------- |
| Authentik   | Create admin account, configure OIDC providers         | [services/infomaniak.md](./services/infomaniak.md) |
| Vaultwarden | Create admin token, enable SSO, create family accounts | [services/bitwarden.md](./services/bitwarden.md)   |
| Portainer   | Create local admin account, configure MFA              | —                                                  |
| WUD         | Verify container watch list                            | —                                                  |

**Verification checklist:**
- [ ] `https://auth.{domain}` — Authentik login page loads
- [ ] `https://vault.{domain}` — Vaultwarden loads, SSO via Authentik works
- [ ] `https://portainer.{domain}` — Portainer UI loads
- [ ] `https://wud.{domain}` — WUD dashboard loads
- [ ] BorgBackup cron configured and first backup runs
- [ ] Healthchecks.io dead-man’s switch receives first ping

### Hearth Initialisation

> **ACTION:** Run the Phase 1 bootstrap to set up the hearth VPS, install Docker, deploy Caddy + Infisical, and generate the BorgBackup SSH key.

The first run bootstraps the bare VPS: creates the deploy user, installs Docker, configures system settings, generates the BorgBackup SSH key pair, and deploys the foundation services (Caddy + Infisical).

GitHub Actions → Select `deploy-hearth` → Run workflow from your feature branch:

| Input     | Value           | Notes                                  |
| --------- | --------------- | -------------------------------------- |
| `branch`  | `deploy/hearth` | Must match the branch you run from     |
| `mode`    | `bootstrap`     | Init server + deploy Caddy & Infisical |
| `dry_run` | `false`         |                                        |

After this run:
- **Caddy + Infisical** are running at `https://secrets.{domain}`
- **BorgBackup public key** is printed in the workflow output (init step logs) — store in Bitwarden for reference
- Complete the manual Infisical setup (steps 3–7 from Phase 1 above)

#### Hearth Initial Setup

Bootstrap the server with Docker, the `haven` service user, directory structure, and SSH hardening.

**Playbook:** `deploy/ansible-init/hearth-init.yml`  
**Runs once** on a fresh server. Safe to re-run — all tasks are idempotent.

| Task                    | Details                                                                    |
| ----------------------- | -------------------------------------------------------------------------- |
| Set timezone            | Configured via `haven_timezone` variable (set in `vars/main.yml`)          |
| Install packages        | `curl`, `ca-certificates`, `gnupg`, `borgbackup`, `fail2ban`, `jq`, others |
| Install Docker          | Official Docker CE repository, pinned version                              |
| Create `haven` user     | System user, home `/opt/haven`, member of `docker` group                   |
| Create directory tree   | `/opt/haven/etc`, `/opt/haven/var/data`, `/opt/haven/var/certs`, etc.      |
| Generate BorgBackup key | `borg_ed25519` SSH key pair in `/opt/haven/.ssh/`                          |
| SSH hardening           | `PermitRootLogin prohibit-password`, `PasswordAuthentication no`           |

#### Hearth Service Directories

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

### Hearth BorgBackup Authorization

> **ACTION:** Ensure BorgBackup SSH key authorization is configured. This happens automatically during `setup` mode.

The borg SSH key upload is **automated** — in `setup` mode, the config playbook uploads the generated `borg_ed25519.pub` key to the Storage Box sub-account via `install-ssh-key` (Hetzner's standard SSH key installation command on port 23), using `STORAGEBOX_PASSWORD` (from Infisical) for authentication. No manual Robot UI step is required.

> The public key is printed in the `bootstrap` workflow output for reference — store it in Bitwarden, but you do not need to add it manually via Hetzner Robot.

> **⚠️ External reachability** must be enabled on the sub-account (covered in [Infrastructure Storage Box](#infrastructure-storage-box)). Without it the automated upload on port 23 will fail.

### Hearth Configure and Deploy

> **ACTION:** Run the Phase 2 full deployment to set up all hearth services.
> **ACTION:** After deployment, save the BorgBackup repokey for future restores.

With Infisical configured and all secrets populated (Phase 1 complete), run the full deployment: fetch secrets from Infisical, initialise the borg repository on the Storage Box, enforce server configuration, and start all Docker Compose services.

GitHub Actions → Select `deploy-hearth` → Run workflow from your feature branch:

| Input     | Value           | Notes                                        |
| --------- | --------------- | -------------------------------------------- |
| `branch`  | `deploy/hearth` | Must match the branch you run from           |
| `mode`    | `setup`         | First full deploy (borg + config + services) |
| `dry_run` | `false`         |                                              |

After this run, the following services should be reachable at their configured subdomains:

| Service     | URL example                  |
| ----------- | ---------------------------- |
| Caddy       | (reverse proxy — no UI)      |
| Authentik   | `https://auth.{domain}`      |
| Vaultwarden | `https://vault.{domain}`     |
| Infisical   | `https://secrets.{domain}`   |
| Portainer   | `https://portainer.{domain}` |
| WUD         | `https://wud.{domain}`       |

**Running containers** (verify with `docker ps` on the server or via Portainer):

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

**Save the BorgBackup repokey** — in the workflow log, find the task **"Show BorgBackup repokey"** → copy the key block and save to Bitwarden as **"Haven BorgBackup repo key"**.

> ⚠️ Without this key + `BORG_PASSPHRASE`, backups **cannot be restored**. The repokey is also shown on every `setup` mode run, so you can retrieve it later if needed.

> **Subsequent deployments** (after config changes): use `mode: deploy`. Optionally set `backup_before_deploy: true` to snapshot before applying changes.

---
