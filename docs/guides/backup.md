# Haven Backup Strategy

> Two-tier backup architecture for Haven's infrastructure and app data: on-premises BorgBackup + remote sync to Infomaniak kDrive.

[← Back to Guide](./index.md)

---

## Overview

Haven employs a **two-tier backup strategy** to protect infrastructure and app data against loss:

- **Tier 1 (Local):** Daily encrypted BorgBackup of Hearth VPS (Authentik, Vaultwarden, system config, and the kSuite email/calendar/contacts mirror) and Forge VPS (Postgres dumps, k3s datastore, app config PVCs) to the `haven-backup` Storage Box.
- **Tier 2 (Offsite):** Daily encrypted sync of both Storage Boxes to Infomaniak kDrive at ~03:00 UTC, providing geographic redundancy and offline copy for disaster recovery.

This strategy ensures:
- **Confidentiality:** Borg repositories encrypted at rest
- **Durability:** Three independent copies (Hearth/Forge SSD during the run, Storage Box, kDrive)
- **Recoverability:** Borg has full versioning; rclone maintains file-level history on kDrive (30-day version history)
- **Monitoring:** Dead-man's switch via Healthchecks.io confirms daily completion

> **kSuite (email/calendar/contacts) backup is implemented** — see [kSuite backup](#ksuite-backup-email--calendarcontacts) below. **kDrive file-level backup (photos/documents) is a separate, not-yet-decided item** — Storage Box capacity/cost for that is being looked at later.

---

## Tier 1 — Local Backups

### BorgBackup (Hearth + Forge)

**Scope:** Authentik DB + config, Vaultwarden DB + config, Hearth system config (`/etc`), plus k3s cluster config and etcd snapshot

**Schedule:** 
- Hearth backup: Daily at 02:00 UTC (cron on Hearth)
- Forge backup: Daily at 02:30 UTC (cron on Forge, staggered after Hearth)

**Retention:**
- Keep 7 daily archives
- Keep 4 weekly archives
- Keep 6 monthly archives

**Encryption:**
- Passphrase stored in Vaultwarden vault
- Algorithm: `repokey-blake2` (Borg's default, requires passphrase for restore)
- SSH transport: ed25519 key, Borg RSH config in backup script

**Files backed up:**

| VPS    | Paths                                    | Notes                                                                                                                                                                                                                                |
| ------ | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Hearth | `/opt/haven/var/data/authentik`          | Authentik PostgreSQL data                                                                                                                                                                                                            |
| Hearth | `/opt/haven/var/data/vaultwarden`        | Vaultwarden SQLite DB                                                                                                                                                                                                                |
| Hearth | `/opt/haven/etc`                         | Caddyfile, docker-compose.yml, .env files                                                                                                                                                                                            |
| Forge  | `/etc/rancher/k3s/`                      | k3s cluster configuration                                                                                                                                                                                                            |
| Forge  | `/opt/haven/var/backup/forge/datastore/` | Online `sqlite3 .backup` of k3s's SQLite/kine datastore (`state.db`) plus the node `token` and `tls/` CA material. **Not** `k3s etcd-snapshot` — this cluster runs without `--cluster-init`, so it is SQLite-backed, not etcd-backed |
| Forge  | `/opt/haven/var/backup/forge/postgres/`  | `pg_dumpall` logical dumps of `immich-postgres` + `nextcloud-postgres`, taken via `kubectl exec` — safe/consistent, unlike a raw file copy of a live DB's data directory                                                             |
| Forge  | `/opt/haven/var/backup/forge/pvc/`       | Tarred `local-path` PVC directories for every **non-database** app volume (Jellyfin config, Kavita config, Gatus history, ...) — discovered dynamically via `kubectl get pv`                                                         |

> The Forge staging directory is recreated at 0700 on each run and deleted again once the borg archive is written, so plaintext database dumps and cluster CA material never persist on the node between runs.

> **Note:** Immich's photo library and Nextcloud/Kavita/Jellyfin's shared documents tree live on the `haven-data` Storage Box (SMB-mounted `hostPath`, not a `local-path` PV) — those are protected by their own Storage Box redundancy + Tier 2 kDrive sync, not by this Borg archive. Only genuinely node-local state (databases, app config/settings) needs the PVC tar/dump step above.

**Status:** ✅ Implemented — runs daily, monitored via Healthchecks.io ping

**Restore procedure:** See [Backup Recovery](#backup-recovery) below.

---

## Tier 2 — Offsite Sync to kDrive

**Scope:** Both Storage Box directories (`haven-backup` + `haven-data`)

**Schedule:** Daily at 03:00 UTC (rclone cron on Hearth)

**Tools:** `rclone` with Infomaniak kDrive remote backend

**Retention:** kDrive's native 30-day version history applies to all synced files

**Encryption:** Files encrypted at rest on kDrive (Infomaniak's standard); rclone can optionally add a second layer via `--crypt` (not yet implemented)

**Configuration:**

```bash
rclone config show # verify kDrive remote is configured
rclone sync --verbose \
  /mnt/haven-backup \
  kdrive:haven-backup \
  --exclude-if-modified-before 2006-01-02

rclone sync --verbose \
  /mnt/haven-data \
  kdrive:haven-data \
  --exclude-if-modified-before 2006-01-02
```

**Monitoring:** Healthchecks.io dead-man's switch — must complete within 6 hours or alert fires

**Status:** ✅ Implemented — BorgBackup + Storage Box sync active

---

## Backup Recovery

### Option 1: Restore from Borg (Hearth/Forge system state)

**When to use:** Hearth/Forge VPS hardware failure, accidental config deletion, or rollback to a known-good state

**Prerequisites:** Borg passphrase (in Vaultwarden) + SSH key to Storage Box + Borg CLI

**Steps:**

1. **List available archives:**
   ```bash
   export BORG_REPO="u604953-sub1@u604953.your-storagebox.de:./hearth"
   export BORG_RSH="ssh -i ~/.ssh/haven_ed25519 -p 23"
   export BORG_PASSPHRASE="<from Vaultwarden>"
   
   borg list $BORG_REPO
   ```

2. **Extract a specific archive:**
   ```bash
   borg extract $BORG_REPO::hearth-2026-09-01T02:00
   ```

3. **Restore to the VPS:** Copy extracted files back to `/opt/haven/etc`, `/opt/haven/var/data`, etc., then `docker compose up -d` to restart services

**Restore testing:** Monthly restore to a temporary VM (see [Risk & Mitigation](../design.md#risk--mitigation))

### Option 1b: Restore Forge Postgres Databases / App Config (Immich, Nextcloud, Jellyfin, Kavita, Gatus)

**When to use:** Forge node loss, corrupted Postgres data, or accidental deletion of a `local-path` PVC (Jellyfin/Kavita config, Gatus history)

**Prerequisites:** Borg passphrase (in Vaultwarden) + SSH key to Storage Box + Borg CLI + `kubectl` access to the (re-provisioned) cluster

**Steps:**

1. **Extract the Forge archive:**
   ```bash
   export BORG_REPO="u604953-sub2@u604953.your-storagebox.de:./forge"
   export BORG_RSH="ssh -i ~/.ssh/haven_ed25519 -p 23"
   export BORG_PASSPHRASE="<from Vaultwarden>"

   borg list $BORG_REPO
   borg extract $BORG_REPO::forge-2026-09-01T02:30
   ```

2. **Restore a Postgres database** (Immich or Nextcloud) — pipe the logical dump back in via `psql`, not a raw file copy:
   ```bash
   kubectl exec -i -n immich deploy/immich-postgres -- \
     psql -U immich < opt/haven/var/backup/forge/postgres/immich-postgres.sql

   kubectl exec -i -n documents deploy/nextcloud-postgres -- \
     psql -U nextcloud < opt/haven/var/backup/forge/postgres/nextcloud-postgres.sql
   ```

3. **Restore a `local-path` PVC's app config/state** (Jellyfin, Kavita, Gatus) — scale the workload to zero first so nothing is writing to the volume, untar the matching archive back onto the PV's directory, then scale back up:
   ```bash
   kubectl scale deployment/jellyfin -n media --replicas=0
   HOST_PATH=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.name=="jellyfin-config") | (.spec.hostPath.path // .spec.local.path)')
   tar xzf opt/haven/var/backup/forge/pvc/media_jellyfin-config.tar.gz -C "$HOST_PATH"
   kubectl scale deployment/jellyfin -n media --replicas=1
   ```

**Restore testing:** Included in the monthly restore drill above — restore each Postgres dump + one PVC tar to a temporary namespace and verify data integrity.

### Option 2: Restore kSuite Email/Calendar/Contacts

**When to use:** A family member accidentally deleted email/calendar events/contacts past kSuite's own trash retention, or the account itself needs restoring after a compromise

**Prerequisites:** Borg passphrase (in Vaultwarden) + SSH key to Storage Box + Borg CLI

**Steps:**

1. **Extract the relevant Hearth archive** (same as Option 1 above) — the kSuite mirror is included at `opt/haven/var/backup/ksuite/`:
   ```bash
   borg extract $BORG_REPO::hearth-2026-09-01T02:00 opt/haven/var/backup/ksuite
   ```

2. **Email (Maildir restore)** — import the extracted Maildir back into the mailbox via `mbsync` in reverse (swap Master/Slave in a throwaway config) or via any mail client's "Import Maildir" feature:
   ```
   opt/haven/var/backup/ksuite/mail/<name>/  — one Maildir per mailbox
   ```

3. **Calendar/contacts (.ics/.vcf restore)** — import the individual files via Infomaniak webmail: Calendar/Contacts → Import → select the relevant `.ics`/`.vcf` file(s):
   ```
   opt/haven/var/backup/ksuite/calendars/<name>/  — one .ics file per event
   opt/haven/var/backup/ksuite/contacts/<name>/   — one .vcf file per contact
   ```

**Restore testing:** Included in the monthly restore drill above — restore a single mailbox/calendar/contact to a scratch location and verify content integrity.

### Option 3: Full Disaster Recovery (All Tiers)

**Scenario:** Total loss of both Hearth and Forge, all Storage Boxes destroyed

**Recovery window:** ~4 hours

1. **Provision new Hearth + Forge VPS** via `deploy-infra.yml` + `deploy-hearth-init.yml` + `deploy-forge-init.yml`
2. **Download backups from kDrive:** Restore both Storage Box directories from kDrive into the new boxes
3. **Mount Storage Boxes:** Connect the new Hearth/Forge to the new Storage Box infrastructure
4. **Restore BorgBackup archives:** Extract latest Borg archives into `/opt/haven/`
5. **Start services:** `docker compose up -d` on Hearth; `strata deploy run` on Forge
6. **Test:** Verify Authentik login, Vaultwarden unlock, Immich photos visible, Jellyfin libraries scan

---

## Monitoring & Alerts

| Check                  | Tool            | Frequency | Alert                | Escalation                             |
| ---------------------- | --------------- | --------- | -------------------- | -------------------------------------- |
| Borg backup completes  | Healthchecks.io | Daily     | 02:00–04:00 UTC      | Email + Slack (if configured)          |
| rclone kDrive sync     | Healthchecks.io | Daily     | 03:00–09:00 UTC      | Email + Slack (if configured)          |
| Storage Box capacity   | Manual review   | Monthly   | Alert at 80% full    | Upgrade box tier (5/10/20 TB)          |
| kDrive version history | Manual review   | Quarterly | Verify 30-day copies | Check kDrive Manager → Files → History |

---

## Restore Testing Schedule

- **Monthly:** Restore a Borg archive to a temporary VM; verify Authentik/Vaultwarden start and data is present
- **Annually:** Full disaster recovery drill (provision new VPS, restore all tiers, verify all services)

---

## kSuite backup (email + calendar/contacts)

**Status:** ✅ Implemented — a previous attempt was dropped for being unverified guesswork (invented CalDAV/CardDAV URLs, unverified `getmail` flags). This implementation uses two mature, purpose-built tools instead of hand-rolled protocol clients: **mbsync** (isync package) for email, **vdirsyncer** for calendar/contacts.

**What Infomaniak's own kSuite already covers:** infrastructure-level durability (Swiss datacenter redundancy, DPA/nFADP/GDPR obligations, kDrive's native 30-day trash + version history).

**What this backup is for (what kSuite's own coverage does NOT protect against):**
- Permanent deletion past kSuite's own retention/trash window
- Account compromise (attacker deletes mail/calendar/contacts via the same legitimate API a real user would use)
- Billing/ToS dispute or account lockout
- Future migration away from Infomaniak without a frantic last-minute IMAP scrape

**Scope:** every family mailbox's email (via IMAP), calendar, and contacts (via CalDAV/CardDAV)

**Schedule:** Daily at 01:30 UTC (cron on Hearth) — 30 minutes before Hearth's own Borg run at 02:00 UTC

**Design — why mbsync + vdirsyncer, not a custom script:**

| Data              | Tool                     | Why                                                                                                                                                                                                                                                             |
| ----------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Email             | `mbsync` (isync package) | Mature, decades-old tool, packaged in Debian. Mirrors IMAP → local Maildir **incrementally** (only new/changed messages after the first run) — this is what makes a *daily* cron affordable                                                                     |
| Calendar/Contacts | `vdirsyncer`             | Mature, purpose-built for exactly this (CalDAV/CardDAV → local vdir). Performs RFC 6764 auto-discovery (`.well-known/caldav`, `.well-known/carddav`) itself — delegates protocol correctness to a real library instead of hand-rolling PROPFIND/REPORT requests |

Both tools are configured as **one-way, read-only mirrors** — a local change or deletion never propagates back and deletes something in the real kSuite mailbox/calendar/address book.

**Where the actual backup history comes from:** mbsync/vdirsyncer only maintain a *current* mirror at `/opt/haven/var/backup/ksuite/` — they don't produce dated snapshots themselves. That directory is included in **Hearth's own daily Borg archive** (conditionally, when `configure_ksuite_backup` is enabled), so point-in-time history and offsite replication come from the *same* Tier 1/Tier 2 pipeline every other Hearth service already uses — not a parallel backup mechanism.

**Credentials:** One Infomaniak **app password** per family mailbox (Manager → Security → App Passwords — same pattern already used for Authentik's SMTP credential, see [infomaniak.md](../services/infomaniak.md)), stored in Infisical as `KSUITE_BACKUP_<NAME>`. Not the account login password.

> ⚠️ **Verify once before trusting the cron job:** run `vdirsyncer discover <pair_name>` manually after first deploy and confirm it actually finds calendar/address-book collections for each mailbox. If kSuite's CalDAV/CardDAV base URL differs from the configured default (`https://mail.infomaniak.com/`), override `ksuite_dav_url` in `vars/main.yml` with the exact URL from that mailbox's own Account Settings → CalDAV/CardDAV configuration page (Infomaniak's official FAQ *"Manually synchronize Contacts & Calendar (macOS apps) using CardDAV/CalDAV"* shows this per-account). The orchestrator script fails loudly (non-zero exit, Healthchecks.io `/fail` ping) if discovery doesn't resolve — it does not silently produce an empty mirror.

**Restore procedure:** See [Backup Recovery](#backup-recovery) below.

---

## Secrets & Credentials

Backup-related secrets stored in **Infisical Cloud:**

| Secret                    | Used by                             | Rotation                                               |
| ------------------------- | ----------------------------------- | ------------------------------------------------------ |
| `BORG_PASSPHRASE_HEARTH`  | Hearth backup                       | Annually                                               |
| `BORG_PASSPHRASE_FORGE`   | Forge backup                        | Annually                                               |
| `KSUITE_BACKUP_<MAILBOX>` | kSuite backup (mbsync + vdirsyncer) | Whenever the app password is regenerated in Infomaniak |
| `HEALTHCHECK_PING_KSUITE` | kSuite backup monitoring            | N/A (URL, not a secret rotation concern)               |
| `KDRIVE_RCLONE_CONFIG`    | rclone sync                         | Quarterly or on Infomaniak password change             |

**Backup encryption key (Borg repokey):**
- Stored in **Vaultwarden vault** (on Hearth)
- If Hearth is destroyed, the repokey is also lost — recovery requires a full Hearth restore from Borg (chicken-and-egg). Mitigation: export the repokey to Bitwarden Cloud quarterly
- **ACTION:** Add annual export of Borg repokey to Bitwarden Cloud (offline backup of the backup key)

---

## Limits & Known Issues

- **k3s datastore is SQLite, not etcd:** this cluster runs without `--cluster-init`, so the Forge backup uses an online `sqlite3 .backup` rather than `k3s etcd-snapshot`. Fine as-is for a single-node cluster — re-check this note if Forge is ever rebuilt with embedded etcd
- **kSuite CalDAV/CardDAV base URL is unverified for this specific tenant:** `vdirsyncer discover` must be run manually once per mailbox after first deploy to confirm the configured `ksuite_dav_url` actually resolves — see the [kSuite backup](#ksuite-backup-email--calendarcontacts) section above. The email side (IMAP via mbsync) has no such caveat — that hostname is already confirmed via Authentik's own SMTP config
- **kDrive file-level backup (photos/documents) not yet implemented:** deliberately deferred — Storage Box capacity/cost for this is being looked at later. Swiss Backup S3 (not kDrive WebDAV mounted as a live Borg repository — WebDAV's locking/metadata semantics aren't a good fit) is the right target if/when this is picked up
- **kDrive sync encrypted only in transit + at rest:** No additional application-level encryption. Mitigation: future `rclone --crypt` layer optional if needed
- **Backup data stored on same Storage Box as live data (currently):** If the box fails, both Tier 1 and live data are at risk. Mitigation: separate `haven-backup` and `haven-data` Storage Box products ensure this split at the product level
