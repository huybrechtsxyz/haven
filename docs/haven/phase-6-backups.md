# Phase 6 — Backups (BorgBackup)

> [← Phase 5](phase-5-service-setup.md) | [← Overview](README.md)

Automated encrypted backups of all service data to a Hetzner Storage Box via BorgBackup.

**Automated:** Backup script + daily cron deployed by `hearth-config.yml`.  
**Manual (one-time):** SSH key exchange with Storage Box, initial repo creation.  
**Estimated time:** 30 minutes for the one-time setup.

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
Server (Hearth)                         Hetzner Storage Box
─────────────────                       ────────────────────
haven user cron (02:00 UTC)
  └─ /opt/haven/scripts/backup.sh  →  hearth_backup@uXXXXXX.your-storagebox.de:./hearth
       reads passphrase from
       /opt/haven/.borg_passphrase
       SSH key: /opt/haven/.ssh/borg_ed25519
```

All three components are deployed and maintained by Ansible:

- `hearth-init.yml` — generates the SSH keypair, initialises the Borg repo (one-time)
- `hearth-config.yml` — deploys `backup.sh`, writes the passphrase file, installs the cron job (every deploy when `configure_borg: true`)

---

## Step 1 — Order the Hetzner Storage Box

In [Hetzner Robot](https://robot.hetzner.com) → Storage Boxes → Order.

- **Product:** BX11 (1 TB, EUR 3.81/month)
- **Location:** NBG1 (same region as the Hearth VPS)

After provisioning, note the hostname: `uXXXXXX.your-storagebox.de`

---

## Step 2 — Generate a BorgBackup passphrase

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Store it immediately in Vaultwarden as: **"Haven BorgBackup passphrase"** — losing it means permanent loss of all backup data.

---

## Step 3 — Add GitHub Secret

In GitHub repository Settings → Secrets and variables → Actions → **New repository secret**:

| Secret name       | Value                    |
| ----------------- | ------------------------ |
| `BORG_PASSPHRASE` | The passphrase from Step 2 |

---

## Step 4 — Configure storagebox in `vars/main.yml`

Edit `deploy/ansible-config/vars/main.yml` and fill in your Storage Box hostname:

```yaml
# leave configure_borg: false for now — set it true only after Step 7
configure_borg: false

storagebox_host: "uXXXXXX.your-storagebox.de"   # fill in your actual hostname
storagebox_subaccount: hearth-backup             # must match sub-account in Hetzner Robot
```

Commit and push this change before running the pipeline.

---

## Step 5 — Run hearth-init (generate SSH key)

Run the pipeline with:

- `run_init: true`
- `run_config: false`
- `run_deploy: false` (optional)

The playbook generates an Ed25519 key at `/opt/haven/.ssh/borg_ed25519` and **prints the public key** in the pipeline log.

Look for the task **"Display borg SSH public key"** in the workflow output and copy the public key.

---

## Step 6 — Authorise the SSH key on the Storage Box

In Hetzner Robot → Storage Box → Sub-accounts:

1. Find or create the sub-account **`hearth_backup`**
2. Paste the public key from Step 5 into the **SSH Public Keys** field
3. Save

Test the connection manually (optional, SSH into the server first):

```bash
ssh -i /opt/haven/.ssh/borg_ed25519 hearth_backup@uXXXXXX.your-storagebox.de
```

---

## Step 7 — Initialise the Borg repository (one-time)

> This must be run **exactly once**. Running it again on an existing repo will fail safely (Borg refuses to re-init a non-empty repo).

Run the hearth-init playbook manually with `configure_borg=true`:

```bash
ansible-playbook deploy/ansible-init/hearth-init.yml \
  -i "<hearth_public_ip>," \
  --private-key ~/.ssh/haven_ed25519 \
  -e configure_borg=true \
  -e storagebox_host=uXXXXXX.your-storagebox.de \
  -e borg_passphrase=<your-passphrase>
```

The playbook will:
1. Initialise the repo with `--encryption=repokey-blake2`
2. Display the **repo key** in the output (task: "Display borg repo key")

**Copy the repo key and store it in Vaultwarden** as **"Haven BorgBackup repo key"**.  
You need both the passphrase AND the repo key to recover from a complete server loss.

---

## Step 8 — Enable automated backups

In `deploy/ansible-config/vars/main.yml`, set:

```yaml
configure_borg: true
```

Commit and push. From this point on, every `run_config: true` pipeline run will:

- Deploy `/opt/haven/scripts/backup.sh` from the Ansible template
- Write the passphrase to `/opt/haven/.borg_passphrase` (mode `0400`, haven-only)
- Install the cron job to run the backup daily at **02:00 UTC**

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
  borg list hearth_backup@uXXXXXX.your-storagebox.de:./hearth
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
  borg list hearth_backup@uXXXXXX.your-storagebox.de:./hearth
'
```

### 3. Extract data

```bash
sudo -u haven bash -c '
  export BORG_RSH="ssh -i /opt/haven/.ssh/borg_ed25519"
  export BORG_PASSPHRASE="$(cat /opt/haven/.borg_passphrase)"
  cd /
  borg extract hearth_backup@uXXXXXX.your-storagebox.de:./hearth::hearth-YYYY-MM-DDTHH:MM
'
```

### 4. Restart services

```bash
docker compose -p haven -f /opt/haven/etc/docker-compose.yml up -d
```

---

## Checklist

- [ ] Hetzner Storage Box ordered (BX11, NBG1)
- [ ] BorgBackup passphrase generated and stored in Vaultwarden
- [ ] `BORG_PASSPHRASE` added to GitHub Secrets
- [ ] `storagebox_host` filled in `deploy/ansible-config/vars/main.yml` and committed
- [ ] SSH key generated (pipeline `run_init=true`, Step 5)
- [ ] SSH public key authorised on Storage Box sub-account in Hetzner Robot (Step 6)
- [ ] Borg repo initialised with `configure_borg=true` (Step 7)
- [ ] Repo key exported and stored in Vaultwarden
- [ ] `configure_borg: true` set in `vars/main.yml` and committed (Step 8)
- [ ] Pipeline `run_config=true` — backup script + cron deployed
- [ ] First backup verified in `/var/log/haven-backup.log`
- [ ] Restore dry run performed
