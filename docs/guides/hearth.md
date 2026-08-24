# Haven Hearth

> This document describes deploying and configuring the Hearth VPS — the core services node.

[← Back to Guide](./index.md)

Hearth is the core VPS. It runs as a single Docker Compose stack on a Hetzner CX23: Caddy, Authentik, Vaultwarden, Portainer, and WUD.

**Prerequisites:** `deploy-infra.yml` must have run successfully (VPS + firewall exist, see [infrastructure.md](./infrastructure.md)), DNS A records must be configured at INWX (see [Infrastructure DNS Records](./infrastructure.md#infrastructure-dns-records)), and all Infisical Cloud secrets must already be populated (see [setup.md](./setup.md)).

> **No bootstrap phase needed.** Infisical is a **SaaS** ([Infisical Cloud](./setup.md#infisical-cloud-setup)), so every secret already exists in Infisical *before* Hearth is ever provisioned. Hearth deploys in one pass. All bootstrap services (Infisical, Terraform Cloud, Bitwarden Cloud) are hosted externally and are not part of the Hearth VPS.

---

## Design decision — Portainer stays on local auth, not SSO

Portainer is **intentionally not** wired through Authentik SSO. Portainer exists to check on and
recover other containers (including Authentik itself), so it must stay reachable even when
Authentik is down, misconfigured, or mid-upgrade — putting it behind the identity provider it may
need to fix would defeat that purpose. Portainer uses its own local admin account instead (create
it + enable MFA on first login).

As a secondary consideration, Portainer CE (the free edition used here) doesn't support OAuth/OIDC
at all — SSO would require upgrading to Portainer Business Edition (free up to 3 nodes / 5 users).
Not a blocker either way, since local auth is the deliberate choice regardless of edition.

Three Ansible playbooks now live at `deploy/ansible-hearth/` driven by three focused GitHub Actions
workflows (`deploy-hearth-init.yml`/`deploy-hearth-config.yml`/`deploy-hearth-deploy.yml`, one per
playbook, sharing the `hetzner-ssh-open`/`hetzner-ssh-close` composite actions for the temporary
firewall window) that resolve every secret via `strata values get` against Infisical Cloud (machine
identity auth, same pattern as `deploy-infra.yml`) instead of raw GitHub Secrets. Vaultwarden's
admin token is fetched pre-hashed as `VAULTWARDEN_ADMIN_ARGON`, and the Storage Box / BorgBackup
secret names match the per-node naming declared in `environment.yaml`
(`STORAGEBOX_HEARTH_PASSWORD`, `BORG_PASSPHRASE_HEARTH`).
The compose stack itself never carried self-hosted Infisical to begin with — `hearth/namespace.yaml`
only declares `caddy`/`authentik`/`vaultwarden`/`portainer`/`wud`.

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

## Hearth Init (`deploy-hearth-init.yml`)

One-time bootstrap of a fresh server: creates the deploy user, installs Docker, configures system settings, and generates the BorgBackup SSH key pair. Safe to re-run — all tasks are idempotent, but normally only needed once per server.

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

| Input            | Value                                                                  | Notes                                              |
| ---------------- | ---------------------------------------------------------------------- | -------------------------------------------------- |
| `branch`         | *your branch*                                                          | Must match the branch the workflow is running on   |
| `dry_run`        | `false`                                                                | `true` skips playbook execution entirely (preview) |
| `configure_borg` | `false` (first run), `true` (once SSH key authorised in Hetzner Robot) | Initialises the BorgBackup repo                    |

---

## Hearth Config (`deploy-hearth-config.yml`)

Idempotent configuration enforcement: security updates, SSH hardening, deploys the BorgBackup backup script + daily cron + passphrase file, (re-)applies the Authentik SSO blueprint, and runs post-config diagnostics. Run this on every routine deploy, immediately before `deploy-hearth-deploy.yml`.

The Storage Box SSH key itself is uploaded once by `deploy-hearth-init.yml` (see above) — this workflow only deploys the backup script/cron that *uses* that already-authorised key.

| Input            | Value         | Notes                                                                                                                                                                                        |
| ---------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `branch`         | *your branch* | Must match the branch the workflow is running on                                                                                                                                             |
| `dry_run`        | `false`       | `true` skips playbook execution entirely (preview)                                                                                                                                           |
| `configure_borg` | `true`        | Deploys/refreshes the BorgBackup script, cron, and passphrase file — leave `true` once Borg has been initialised via `deploy-hearth-init.yml`, only set `false` before that's ever been done |

---

## Hearth Deploy (`deploy-hearth-deploy.yml`)

Deploys the Docker Compose stack (Caddy, Authentik, Vaultwarden, Portainer, WUD). Run after `deploy-hearth-config.yml` on every routine deploy.

GitHub Actions → Select `Hearth - Deploy` → Run workflow from your feature branch.

| Input                  | Value         | Notes                                                                                      |
| ---------------------- | ------------- | ------------------------------------------------------------------------------------------ |
| `branch`               | *your branch* | Must match the branch the workflow is running on                                           |
| `dry_run`              | `false`       | `true` skips playbook execution entirely (preview only)                                    |
| `full_restart`         | `false`       | Stops **all** containers before deploying — use only when containers have stale state      |
| `backup_before_deploy` | `false`       | Runs a BorgBackup snapshot before deploying (requires `configure_borg: true` already done) |

All secrets referenced by `deploy-hearth-deploy.yml` are declared in [setup.md](./setup.md) — `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_POSTGRESQL__PASSWORD`, `VAULTWARDEN_ADMIN_ARGON` (the precomputed Argon2 hash written into the container's `VAULTWARDEN_ADMIN_TOKEN` env var), `VAULTWARDEN_SSO_CLIENT_SECRET`, `WUD_SSO_CLIENT_SECRET`, plus the per-node Storage Box (`STORAGEBOX_HEARTH_PASSWORD`) and BorgBackup (`BORG_PASSPHRASE_HEARTH`) values (the latter two used by `deploy-hearth-init.yml`/`deploy-hearth-config.yml` too). All three workflows resolve their secrets from Infisical Cloud at runtime via `strata values get` (machine identity auth) — none are read from raw GitHub Secrets. Portainer has no SSO secret by design — see **Design decision** above.

**Routine deployments** (after `deploy-hearth-init.yml` has succeeded once): run `deploy-hearth-config.yml` then `deploy-hearth-deploy.yml`, in that order, every time. Optionally set `backup_before_deploy: true` on the deploy run to snapshot before applying changes.

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

| Service     | Post-deploy steps                                                         | Guide                                                      |
| ----------- | ------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Authentik   | Create admin account, configure OIDC providers for Vaultwarden/WUD        | [services/infomaniak.md](../services/infomaniak.md) (SMTP) |
| Vaultwarden | Create admin account, enable SSO, create family accounts                  | [services/bitwarden.md](../services/bitwarden.md)          |
| Portainer   | Create local admin account, configure MFA (local auth by design, not SSO) | —                                                          |
| WUD         | Verify container watch list                                               | —                                                          |

## Verification checklist

- [ ] `https://auth.{domain}` — Authentik login page loads
- [ ] `https://vault.{domain}` — Vaultwarden loads, SSO via Authentik works
- [ ] `https://portainer.{domain}` — Portainer UI loads
- [ ] `https://wud.{domain}` — WUD dashboard loads
- [ ] BorgBackup cron configured and first backup runs
- [ ] Healthchecks.io dead-man's switch receives first ping

