# Phase 6 — Backups (BorgBackup)

> [← Phase 5](phase-5-service-setup.md) | [← Overview](README.md)

Automated encrypted backups of all service data to a Hetzner Storage Box via BorgBackup.

**Manual prerequisites (one-time):** Order Storage Box, generate passphrase, add GitHub Secret, fill in hostname.
**Unavoidable manual action:** Paste the SSH public key into Hetzner Robot (web UI only).
**Everything else:** Pipeline runs.

---

## What gets backed up

| Directory                          | Contents                                  |
| ---------------------------------- | ----------------------------------------- |
| `/opt/haven/var/data/authentik/`   | Authentik PostgreSQL data + media uploads |
| `/opt/haven/var/data/vaultwarden/` | Vaultwarden database (all passwords)      |
| `/opt/haven/var/data/infisical/`   | Infisical PostgreSQL data                 |
| `/opt/haven/etc/`                  | docker-compose.yml, Caddyfile             |

> **Not backed up:** TLS certificates — Caddy re-obtains these from Let's Encrypt automatically.
> **Not backed up:** Container images — re-pulled on next deploy.

**Retention policy:** 7 daily, 4 weekly, 6 monthly archives (configurable in `vars/main.yml`).

---

## Architecture

```
Server (Hearth)                          Hetzner Storage Box
────────────────                         ─────────────────────
haven user cron (02:00 UTC)
  └─ /opt/haven/scripts/backup.sh  →   hearth_backup@u604953.your-storagebox.de:./hearth
       reads: /opt/haven/.borg_passphrase  (mode 0400)
       key:   /opt/haven/.ssh/borg_ed25519
```

| Component               | Managed by          | When                                       |
| ----------------------- | ------------------- | ------------------------------------------ |
| SSH keypair + repo init | `hearth-init.yml`   | Once (pipeline Steps 1 + 3)                |
| Backup script + cron    | `hearth-config.yml` | Every deploy (when `configure_borg: true`) |

---

## Prerequisites (manual, one-time)

Complete these before running any pipeline step.

### 1. Order Hetzner Storage Box

[Hetzner Robot](https://robot.hetzner.com) → Storage Boxes → Order

- **Product:** BX11 (1 TB, EUR 3.81/month)
- **Location:** NBG1 (same region as Hearth VPS)

Hostname after provisioning: `u604953.your-storagebox.de`

### 2. Add GitHub Secret

GitHub repo → Settings → Secrets and variables → Actions → Environments → **production** → New secret:

| Secret name       | Value                                                       |
| ----------------- | ----------------------------------------------------------- |
| `BORG_PASSPHRASE` | Passphrase generated in [Phase 0](phase-0-prerequisites.md) |

### 3. Set storagebox hostname in `vars/main.yml`

`deploy/ansible-config/vars/main.yml` is already set to `u604953.your-storagebox.de`. Verify and commit if not already done.

---

## Pipeline setup

### Step 1 — Generate SSH key

Run pipeline with:

| Input            | Value   |
| ---------------- | ------- |
| `run_init`       | `true`  |
| `configure_borg` | `false` |
| `run_config`     | `false` |
| `run_deploy`     | `false` |

In the workflow log, find task **"Display borg SSH public key"** and copy the `ssh-ed25519 ...` line.

---

### Step 2 — Authorise the SSH key *(manual — Hetzner Robot web UI)*

> This is the only step that cannot be automated. Hetzner Robot has no API for SSH key management on Storage Box sub-accounts.

[Hetzner Robot](https://robot.hetzner.com) → Storage Boxes → `u604953` → Sub-accounts → `hearth_backup` → SSH Keys → paste the key → Save.

---

### Step 3 — Initialise the Borg repository

Run pipeline with:

| Input            | Value   |
| ---------------- | ------- |
| `run_init`       | `true`  |
| `configure_borg` | `true`  |
| `run_config`     | `false` |
| `run_deploy`     | `false` |

> Run this **exactly once**. Borg refuses to re-init a non-empty repo, so re-running is safe but a no-op.

The pipeline will:
1. Initialise the repo with `--encryption=repokey-blake2`
2. Print the **repo key** under task **"Display borg repo key"**

Copy the repo key and save to Vaultwarden as **"Haven BorgBackup repo key"**. You need both the passphrase and the repo key to recover from a total server loss.

---

### Step 4 — Enable automated backups

In `deploy/ansible-config/vars/main.yml`, set:

```yaml
configure_borg: true
```

Commit and push, then run the pipeline with `run_config: true`. This deploys:
- `/opt/haven/scripts/backup.sh` (Jinja2-rendered, haven-owned, mode `0750`)
- `/opt/haven/.borg_passphrase` (mode `0400`, haven-only)
- Cron job: daily at **02:00 UTC** as `haven` user

---

## Verifying backups

### Check the backup log

```bash
tail -50 /var/log/haven-backup.log
```

### List all archives

```bash
sudo -u haven bash -c '
  export BORG_RSH="ssh -i /opt/haven/.ssh/borg_ed25519"
  export BORG_PASSPHRASE="$(cat /opt/haven/.borg_passphrase)"
  borg list hearth_backup@u604953.your-storagebox.de:./hearth
'
```

### Run a manual backup

```bash
sudo -u haven /opt/haven/scripts/backup.sh
```

---

## Restore procedure

### 1. Stop services

```bash
docker compose -p haven -f /opt/haven/etc/docker-compose.yml down
```

### 2. List available archives

```bash
sudo -u haven bash -c '
  export BORG_RSH="ssh -i /opt/haven/.ssh/borg_ed25519"
  export BORG_PASSPHRASE="$(cat /opt/haven/.borg_passphrase)"
  borg list hearth_backup@u604953.your-storagebox.de:./hearth
'
```

### 3. Extract data

```bash
sudo -u haven bash -c '
  export BORG_RSH="ssh -i /opt/haven/.ssh/borg_ed25519"
  export BORG_PASSPHRASE="$(cat /opt/haven/.borg_passphrase)"
  cd /
  borg extract hearth_backup@u604953.your-storagebox.de:./hearth::hearth-YYYY-MM-DDTHH:MM
'
```

### 4. Restart services

```bash
docker compose -p haven -f /opt/haven/etc/docker-compose.yml up -d
```

---

## Checklist

- [x] Hetzner Storage Box ordered (`u604953.your-storagebox.de`)
- [x] BorgBackup passphrase generated and stored in Vaultwarden
- [x] `BORG_PASSPHRASE` added to GitHub Secrets
- [x] `storagebox_host` set in `deploy/ansible-config/vars/main.yml`
- [x] SSH key generated — pipeline Step 1 (`run_init=true, configure_borg=false`)
- [x] SSH public key authorised on `hearth_backup` sub-account in Hetzner Robot
- [ ] Borg repo initialised — pipeline Step 3 (`run_init=true, configure_borg=true`)
- [ ] Repo key saved to Vaultwarden
- [ ] `configure_borg: true` set in `vars/main.yml` and committed
- [ ] Pipeline `run_config=true` — backup script + cron deployed
- [ ] First backup verified in `/var/log/haven-backup.log`
- [ ] Restore dry run performed
