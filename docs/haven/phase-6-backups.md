# Phase 6 — Backups (BorgBackup)

> [← Phase 5](phase-5-service-setup.md) | [← Overview](README.md)

Set up automated encrypted backups of all service data to the Hetzner Storage Box.

**Automated:** BorgBackup cron on the server (after one-time manual setup).  
**Manual:** SSH key exchange with Storage Box, initial repo creation, passphrase storage.  
**Estimated time:** 30 minutes setup.

---

## What needs to be backed up

| Directory                          | Contents                                  |
| ---------------------------------- | ----------------------------------------- |
| `/opt/haven/var/data/authentik/`   | Authentik PostgreSQL data + media uploads |
| `/opt/haven/var/data/vaultwarden/` | Vaultwarden database (all passwords)      |
| `/opt/haven/var/data/infisical/`   | Infisical PostgreSQL data                 |
| `/opt/haven/etc/`                  | docker-compose.yml, Caddyfile             |

> **Not backed up:** TLS certificates (`/opt/haven/var/certs/`) — Caddy re-obtains these automatically from Let's Encrypt.

> **Not backed up separately:** Container images — re-pulled on next deploy.

---

## 6.1 — Generate a BorgBackup passphrase

Generate a strong passphrase and store it in Vaultwarden immediately:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Store this in Vaultwarden as: **"Haven BorgBackup passphrase"** — losing it means losing access to all backups.

---

## 6.2 — Set up SSH access to the Storage Box

On the **server** (SSH in as root or haven):

```bash
# Generate a key specifically for the Storage Box
ssh-keygen -t ed25519 -C "hearth-borgbackup" -f /root/.ssh/borg_ed25519 -N ""

# Copy the public key to the Storage Box
# Replace uXXXXXX with your Storage Box username
ssh-copy-id -i /root/.ssh/borg_ed25519.pub hearth_backup@uXXXXXX.your-storagebox.de
```

Test the connection:

```bash
ssh -i /root/.ssh/borg_ed25519 hearth_backup@uXXXXXX.your-storagebox.de
```

---

## 6.3 — Initialize the Borg repository

On the **server**:

```bash
export BORG_PASSPHRASE="your-passphrase-from-61"
export BORG_RSH="ssh -i /root/.ssh/borg_ed25519"
export BORG_REPO="ssh://hearth_backup@uXXXXXX.your-storagebox.de:23/./haven-hearth"

# Initialize (once)
borg init --encryption=repokey-blake2 "$BORG_REPO"

# Export and store the repo key in Vaultwarden too
borg key export "$BORG_REPO" /tmp/borg-repo-key.txt
cat /tmp/borg-repo-key.txt
# → copy this into Vaultwarden alongside the passphrase
rm /tmp/borg-repo-key.txt
```

---

## 6.4 — Create the backup script

On the **server**, create `/opt/haven/scripts/backup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

export BORG_PASSPHRASE="your-passphrase"
export BORG_RSH="ssh -i /root/.ssh/borg_ed25519"
export BORG_REPO="ssh://hearth_backup@uXXXXXX.your-storagebox.de:23/./haven-hearth"

ARCHIVE="hearth-$(date +%Y-%m-%dT%H:%M)"

borg create \
  --verbose \
  --filter AME \
  --list \
  --stats \
  --show-rc \
  --compression lz4 \
  --exclude-caches \
  "$BORG_REPO::$ARCHIVE" \
  /opt/haven/var/data/authentik \
  /opt/haven/var/data/vaultwarden \
  /opt/haven/var/data/infisical \
  /opt/haven/etc

# Prune: keep 7 daily, 4 weekly, 6 monthly
borg prune \
  --list \
  --glob-archives "hearth-*" \
  --show-rc \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  "$BORG_REPO"

# Compact freed space
borg compact "$BORG_REPO"
```

```bash
chmod +x /opt/haven/scripts/backup.sh
```

> **Note:** Store the passphrase in the script only after confirming it's protected (root-only readable, not in git). Long-term, consider storing it in Infisical and fetching at runtime.

---

## 6.5 — Schedule with cron

```bash
# Add to root crontab
crontab -e

# Run daily at 02:00 UTC
0 2 * * * /opt/haven/scripts/backup.sh >> /var/log/haven-backup.log 2>&1
```

---

## 6.6 — Test the backup and restore

### Test backup runs

```bash
/opt/haven/scripts/backup.sh

# List archives
borg list "$BORG_REPO"
```

### Test a restore (dry run)

```bash
# Extract a specific file to verify it's readable
borg extract --dry-run "$BORG_REPO::hearth-<latest>" opt/haven/etc/docker-compose.yml
```

### Full restore procedure

```bash
# Stop services first
docker compose -p haven -f /opt/haven/etc/docker-compose.yml down

# Restore all data
cd /
borg extract "$BORG_REPO::hearth-<archive-name>"

# Restart services
docker compose -p haven -f /opt/haven/etc/docker-compose.yml up -d
```

---

## Checklist

- [ ] BorgBackup passphrase generated and stored in Vaultwarden
- [ ] SSH key created on server for Storage Box access
- [ ] SSH connection to Storage Box verified
- [ ] Borg repo initialized with `--encryption=repokey-blake2`
- [ ] Repo key exported and stored in Vaultwarden
- [ ] Backup script created at `/opt/haven/scripts/backup.sh`
- [ ] Manual test run successful (`borg list` shows an archive)
- [ ] Restore dry run successful
- [ ] Cron job scheduled (daily at 02:00 UTC)
