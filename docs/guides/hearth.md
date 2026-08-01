# Haven Hearth

> This document describes deploying and configuring the Hearth VPS — the core services node.

[← Back to Guide](./index.md)

Hearth is the core VPS. It runs as a single Docker Compose stack on a Hetzner CX23: Caddy, Authentik, Vaultwarden, Portainer, and WUD.

**Prerequisites:** `deploy-infra.yml` must have run successfully (VPS + firewall exist, see [infrastructure.md](./infrastructure.md)), DNS A records must be configured at INWX (see [Infrastructure DNS Records](./infrastructure.md#infrastructure-dns-records)), and all Infisical Cloud secrets must already be populated (see [setup.md](./setup.md)).

> **No bootstrap phase needed.** Infisical is a **SaaS** ([Infisical Cloud](./setup.md#infisical-cloud-setup)), so every secret already exists in Infisical *before* Hearth is ever provisioned. Hearth deploys in one pass. All bootstrap services (Infisical, Terraform Cloud, Bitwarden Cloud) are hosted externally and are not part of the Hearth VPS.

---

## ⚠️ Known gaps before this matches reality

This guide describes the **intended** deployment, matching the secrets/Infisical Cloud model established in [setup.md](./setup.md). The actual code hasn't fully caught up yet:

| Gap                                                      | Where                                                                                                                                                | What needs to happen                                                                                                                    |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Ansible playbooks missing from active repo               | `deploy-hearth.yml` runs `deploy/ansible-init`, `deploy/ansible-config`, `deploy/ansible-deploy` — none of these exist outside `.archive/v1/deploy/` | Restore/update the three playbooks at their new paths before this workflow can run at all                                               |
| Self-hosted Infisical still in the compose stack         | `hearth/docker-compose.yml` still defines `infisical`, `infisical-db`, `infisical-redis`                                                             | Remove — Infisical Cloud replaces it entirely                                                                                           |
| Secrets fetched from GitHub Secrets, not Infisical Cloud | `deploy-hearth.yml` reads `AUTHENTIK_SECRET_KEY`, `VAULTWARDEN_ADMIN_TOKEN`, etc. straight from `secrets.*`                                          | Update the workflow to fetch from Infisical Cloud at runtime via the machine identity (`INFISICAL_CLIENT_ID`/`INFISICAL_CLIENT_SECRET`) |
| Vaultwarden admin token hashing                          | Workflow passes `VAULTWARDEN_ADMIN_TOKEN` directly                                                                                                   | Needs the raw-token + deploy-time-hash flow — see [setup.md → Secrets for Vaultwarden](./setup.md#secrets-for-vaultwarden)              |
| Storage Box secret/variable naming mismatch              | `deploy-hearth.yml` uses `HETZNER_STORAGEBOX_PASSWORD` / `vars.STORAGEBOX_SUBACCOUNT_HEARTH`                                                         | Align with the per-node naming in [setup.md → Secrets for Hetzner Storagebox](./setup.md#secrets-for-hetzner-storagebox)                |
| Portainer SSO not wired up                               | `PORTAINER_SSO_CLIENT_SECRET` is documented but the `portainer` service has no OIDC env vars in `docker-compose.yml`                                 | Add OIDC config to the Portainer service definition                                                                                     |

---

## What gets deployed

| Service                                        | Purpose                                       | URL                          |
| ---------------------------------------------- | --------------------------------------------- | ---------------------------- |
| Caddy                                          | Reverse proxy + automatic TLS (Let's Encrypt) | — (fronts everything below)  |
| Authentik (server + worker + Postgres + Redis) | SSO / OIDC identity provider                  | `https://auth.{domain}`      |
| Vaultwarden                                    | Password manager                              | `https://vault.{domain}`     |
| Portainer                                      | Container management UI                       | `https://portainer.{domain}` |
| WUD (What's Up Docker)                         | Container update notifier                     | `https://wud.{domain}`       |

There is no `secrets.{domain}` entry. Infisical Cloud is hosted by Infisical, not by Hearth.

---

## Hearth Initialisation (`run_init`)

One-time bootstrap of a fresh server: creates the deploy user, installs Docker, configures system settings, and generates the BorgBackup SSH key pair. Safe to re-run — all tasks are idempotent.

| Task                    | Details                                                                    |
| ----------------------- | -------------------------------------------------------------------------- |
| Set timezone            | Configured via `haven_timezone` variable                                   |
| Install packages        | `curl`, `ca-certificates`, `gnupg`, `borgbackup`, `fail2ban`, `jq`, others |
| Install Docker          | Official Docker CE repository, pinned version                              |
| Create `haven` user     | System user, home `/opt/haven`, member of `docker` group                   |
| Create directory tree   | `/opt/haven/etc`, `/opt/haven/var/data`, `/opt/haven/var/certs`, etc.      |
| Generate BorgBackup key | `borg_ed25519` SSH key pair in `/opt/haven/.ssh/`                          |
| SSH hardening           | `PermitRootLogin prohibit-password`, `PasswordAuthentication no`           |

**Service directories:**

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
        └── vaultwarden/
```

Optionally set `configure_borg: true` on this run to also initialise the BorgBackup repo on the Storage Box — only after the SSH key has been authorised (see below).

---

## Hearth Configuration (`run_config`)

Idempotent configuration enforcement: uploads the BorgBackup SSH key to the Storage Box sub-account, writes the backup script, and configures monitoring.

**BorgBackup authorization is automated** — the config playbook uploads the generated `borg_ed25519.pub` key to the Storage Box sub-account via `install-ssh-key` (Hetzner's standard SSH key installation command on port 23), using the Storage Box password (from Infisical). No manual Hetzner Robot step is required.

> **⚠️ External reachability** must be enabled on the sub-account (see [Secrets for Hetzner Storagebox](./setup.md#secrets-for-hetzner-storagebox)). Without it, the automated upload on port 23 will fail.

---

## Hearth Deploy (`run_deploy`)

Deploys the Docker Compose stack (Caddy, Authentik, Vaultwarden, Portainer, WUD).

GitHub Actions → Select `deploy-hearth` → Run workflow from your feature branch. The actual inputs on the current workflow:

| Input                  | Value                                                   | Notes                                                                                      |
| ---------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `branch`               | *your branch*                                           | Must match the branch the workflow is running on                                           |
| `dry_run`              | `false`                                                 | `true` skips playbook execution entirely (preview only)                                    |
| `run_init`             | `true` (first run only)                                 | One-time server initialisation                                                             |
| `configure_borg`       | `true` (only after SSH key authorised in Hetzner Robot) | Initialises the BorgBackup repo                                                            |
| `run_config`           | `true`                                                  | Idempotent configuration enforcement                                                       |
| `run_deploy`           | `true`                                                  | Deploys the Docker Compose services                                                        |
| `full_restart`         | `false`                                                 | Stops **all** containers before deploying — use only when containers have stale state      |
| `backup_before_deploy` | `false`                                                 | Runs a BorgBackup snapshot before deploying (requires `configure_borg: true` already done) |

All secrets referenced by this run are declared in [setup.md](./setup.md) — `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_POSTGRESQL__PASSWORD`, `VAULTWARDEN_ADMIN_TOKEN_RAW` (hashed to `VAULTWARDEN_ADMIN_TOKEN` at deploy time), `VAULTWARDEN_SSO_CLIENT_SECRET`, `WUD_SSO_CLIENT_SECRET`, `PORTAINER_SSO_CLIENT_SECRET`, plus the Storage Box and BorgBackup values. See the **Known gaps** table above — as of this rebuild, these still come from GitHub Secrets rather than Infisical Cloud.

**Subsequent deployments** (after config changes, once `run_init` and `configure_borg` have succeeded once): set `run_init: false`, `configure_borg: false`, and leave `run_config: true` / `run_deploy: true`. Optionally set `backup_before_deploy: true` to snapshot before applying changes.

**Verify the running containers** — via `docker ps` on the server, or through Portainer:

| Container                  | Service              | Port           |
| -------------------------- | -------------------- | -------------- |
| `haven-caddy-1`            | Caddy reverse proxy  | 80, 443        |
| `haven-authentik-server-1` | Authentik server     | (behind Caddy) |
| `haven-authentik-worker-1` | Authentik worker     | —              |
| `haven-authentik-redis-1`  | Authentik Redis      | —              |
| `haven-authentik-db-1`     | Authentik PostgreSQL | —              |
| `haven-vaultwarden-1`      | Vaultwarden          | (behind Caddy) |
| `haven-portainer-1`        | Portainer            | (behind Caddy) |
| `haven-wud-1`              | WUD                  | (behind Caddy) |

**Save the BorgBackup repokey** — in the workflow log, find the task **"Show BorgBackup repokey"** → copy the key block and save to Bitwarden as "Haven BorgBackup repo key".

> ⚠️ Without this key + `BORG_PASSPHRASE`, backups **cannot be restored**. The repokey is shown on every `configure_borg: true` run, so it can be retrieved again later if needed.

---

## Post-deploy configuration

| Service     | Post-deploy steps                                                            | Guide                                                      |
| ----------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Authentik   | Create admin account, configure OIDC providers for Vaultwarden/Portainer/WUD | [services/infomaniak.md](../services/infomaniak.md) (SMTP) |
| Vaultwarden | Create admin account, enable SSO, create family accounts                     | [services/bitwarden.md](../services/bitwarden.md)          |
| Portainer   | Create local admin account, configure MFA                                    | —                                                          |
| WUD         | Verify container watch list                                                  | —                                                          |

## Verification checklist

- [ ] `https://auth.{domain}` — Authentik login page loads
- [ ] `https://vault.{domain}` — Vaultwarden loads, SSO via Authentik works
- [ ] `https://portainer.{domain}` — Portainer UI loads
- [ ] `https://wud.{domain}` — WUD dashboard loads
- [ ] BorgBackup cron configured and first backup runs
- [ ] Healthchecks.io dead-man's switch receives first ping

