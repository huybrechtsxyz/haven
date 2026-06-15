# Haven Backup & Disaster Recovery

## Overview

Hearth uses BorgBackup for data protection. Backups run daily via cron on the Hearth VM and store encrypted, deduplicated archives on a Hetzner Storage Box.

- **Backup script:** `deploy/ansible-config/templates/backup.sh.j2` (deployed to `/opt/haven/scripts/backup.sh`)
- **Storage:** Hetzner Storage Box sub-account (`u604953-sub1@u604953.your-storagebox.de`) over SSH port 23
- **Repository path on Storage Box:** `./hearth`

---

## What gets backed up

| Path on server | Contents |
| --- | --- |
| `/opt/haven/var/data/authentik` | Authentik PostgreSQL database + media |
| `/opt/haven/var/data/vaultwarden` | Vaultwarden vault database (SQLite) |
| `/opt/haven/var/data/infisical` | Infisical PostgreSQL database |
| `/opt/haven/etc` | Rendered config files, Caddyfile, `.env`, Authentik blueprint, backup script |

**Not backed up:** `/opt/haven/var/certs` (Caddy TLS certificates — re-issued automatically via ACME on restore).

---

## Retention policy

Configured in `deploy/ansible-config/vars/main.yml`:

| Window | Keep |
| --- | --- |
| Daily | 7 archives |
| Weekly | 4 archives |
| Monthly | 6 archives |

---

## Backup triggers

### 1. Scheduled — daily cron

The cron job is installed by `hearth-config.yml` and runs daily at **02:00 UTC** as the `haven` user:

```
/opt/haven/scripts/backup.sh >> /var/log/haven-backup.log 2>&1
```

If `HEALTHCHECK_PING_URL_BACKUP` is set, the script pings healthchecks.io on start and success.

### 2. Pre-deploy snapshot — `backup_before_deploy`

The `Deploy - haven` workflow has a `backup_before_deploy` toggle. When enabled, it runs the backup script on the server before any containers are changed. Use this for any deploy that modifies service configuration or updates container images.

### 3. On-demand — `Backup - haven` workflow

The standalone `backup.yml` workflow allows a manual backup at any time from the Actions tab. Use this before risky changes or as part of a recovery check.

---

## Critical artifacts — do not lose

| Artifact | Where to keep it | Why |
| --- | --- | --- |
| `BORG_PASSPHRASE` | GitHub Secret + offline copy | Encrypts every archive — without it, all data is unreadable |
| Borg repokey | Offline (printed or offline password manager) | Required together with passphrase to access archives — exported and printed by `hearth-config.yml` |
| `INFISICAL_ENCRYPTION_KEY` | GitHub Secret + offline copy | Encrypts all secrets stored in Infisical — without it, the Infisical DB restore is unusable |

> The repokey is printed to the pipeline log by the **Export BorgBackup repokey** step in `hearth-config.yml`. Copy it out after every fresh init.

---

## Verifying backups

List all archives in the repository:

```bash
export BORG_PASSPHRASE="$(cat /opt/haven/.borg_passphrase)"
export BORG_RSH="ssh -i /opt/haven/.ssh/borg_ed25519 -p 23 -o StrictHostKeyChecking=yes"

borg list u604953-sub1@u604953.your-storagebox.de:./hearth
```

Inspect a specific archive:

```bash
borg list u604953-sub1@u604953.your-storagebox.de:./hearth::hearth-2026-06-14T02:00
```

Check repository integrity:

```bash
borg check u604953-sub1@u604953.your-storagebox.de:./hearth
```

---

## Disaster recovery — full Hearth restore

Use this procedure when the Hearth VM is lost and must be rebuilt from scratch.

### Prerequisites — have these before you start

- `BORG_PASSPHRASE`
- Borg repokey (if you need to import it on a fresh machine)
- All GitHub Secrets intact (verified in the `production` environment settings)

---

### Step 1 — Provision new VM

Run the deploy workflow with `run_init=true` and `configure_borg=true`.

This will:

- Provision a new Hetzner VM via Terraform
- Run `hearth-init.yml`: OS baseline, Docker, `haven` user, directory tree, Borg SSH key generation, Storage Box key upload, host key scan

The Borg SSH key is regenerated on the new host and automatically uploaded to the Storage Box sub-account.

> ⚠️ The **Borg repository is not re-initialised** — the existing Storage Box repo is reused. The `hearth-init.yml` playbook only inits a new repo when one does not already exist. Existing archives are preserved.

---

### Step 2 — Restore data from backup

SSH into the new server and restore the data directories **before starting any containers**.

```bash
ssh -i ~/.ssh/haven_ed25519 root@<new-hearth-ip>

export BORG_PASSPHRASE="$(cat /opt/haven/.borg_passphrase)"
export BORG_RSH="ssh -i /opt/haven/.ssh/borg_ed25519 -p 23 -o StrictHostKeyChecking=yes"
export BORG_REPO="u604953-sub1@u604953.your-storagebox.de:./hearth"

# List available archives and pick the latest healthy one
borg list "$BORG_REPO"

# Restore into / (borg extracts paths relative to the archive root)
cd /
borg extract "$BORG_REPO::hearth-<YYYY-MM-DDTHH:MM>" \
  opt/haven/var/data/authentik \
  opt/haven/var/data/vaultwarden \
  opt/haven/var/data/infisical \
  opt/haven/etc
```

> If you only need to recover Vaultwarden, extract just `opt/haven/var/data/vaultwarden`.

Fix ownership after extraction (Authentik containers run as uid 1000):

```bash
chown -R 1000:1000 /opt/haven/var/data/authentik/media
chown -R 1000:1000 /opt/haven/etc/authentik/templates
```

---

### Step 3 — Apply config and deploy services

Run the deploy workflow with `run_config=true` and `run_deploy=true` (leave `run_init=false` — the server is already initialised).

This will:

- Deploy the Authentik blueprint
- Render the `.env` file with all secrets
- Start all containers via Docker Compose

---

### Step 4 — Validate recovery

| Check | How |
| --- | --- |
| Vaultwarden vault contents | Log in to `https://vault.huybrechts.xyz` — confirm vault items visible |
| Authentik users and groups | Admin Interface → Directory → Users |
| Infisical secrets | Log in to Infisical and verify secrets are present |
| Backup cron | `crontab -u haven -l` on the server |
| Next backup succeeds | Check `/var/log/haven-backup.log` the following day, or trigger the on-demand backup workflow |

---

### Step 5 — Post-restore hardening

- Copy the new Borg repokey from the pipeline log and store it offline.
- Rotate `AUTHENTIK_SECRET_KEY` if the old VM was compromised (all sessions will be invalidated).
- Rotate `VAULTWARDEN_SSO_CLIENT_SECRET` and `WUD_SSO_CLIENT_SECRET` and re-run config to apply the new blueprint.
- Verify healthchecks.io resumes receiving backup pings.
