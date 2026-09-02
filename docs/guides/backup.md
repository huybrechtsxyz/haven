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
- Passphrase source of truth: **Infisical Cloud** (`BORG_PASSPHRASE_HEARTH`/`_FORGE`) — a human-readable copy is also kept in Vaultwarden for convenience, but Infisical is what a real restore actually reads from (see [Backup Recovery](#backup-recovery)'s note on why)
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

**When to use:** Hearth VPS hardware failure, accidental config deletion, or rollback to a known-good state

**Prerequisites:** Borg passphrase (`BORG_PASSPHRASE_HEARTH` in **Infisical Cloud** — the copy in Vaultwarden is a human-readable convenience mirror, not the source of truth) + SSH key to Storage Box + Borg CLI

> **Why Infisical, not Vaultwarden:** Vaultwarden itself runs *on Hearth* — if Hearth is gone, so is Vaultwarden, and you'd need the passphrase to restore Vaultwarden in the first place (a circular dependency). Infisical Cloud is an independent SaaS with no such dependency, which is why it's the real source of truth for this value.

**Steps:**

1. **List available archives:**
   ```bash
   export BORG_REPO="u604953-sub1@u604953.your-storagebox.de:./hearth"
   export BORG_RSH="ssh -i ~/.ssh/haven_ed25519 -p 23"
   export BORG_PASSPHRASE="<strata values get BORG_PASSPHRASE_HEARTH>"

   borg list $BORG_REPO
   ```

2. **Extract a specific archive:**
   ```bash
   borg extract $BORG_REPO::hearth-2026-09-01T02:00
   ```

3. **Restore to the VPS:** Copy extracted files back to `/opt/haven/etc`, `/opt/haven/var/data`, etc., then `docker compose up -d` to restart services

**Restore testing:** Monthly restore to a temporary VM (see [Risk & Mitigation](../design.md#risk--mitigation))

### Option 1b: Restore Forge Postgres Databases / App Config (Immich, Nextcloud, Jellyfin, Kavita, Gatus)

**When to use:** Corrupted Postgres data, or accidental deletion of a `local-path` PVC (Jellyfin/Kavita config, Gatus history), on an *existing, still-running* Forge cluster.

> For a **totally destroyed** Forge (VPS gone, cluster gone), don't start here — go to [Option 3](#option-3-full-disaster-recovery-all-tiers). Restoring these dumps only makes sense once `strata deploy run` has recreated the namespaces/pods/PVCs to restore *into*.

**Prerequisites:** Borg passphrase (`BORG_PASSPHRASE_FORGE` in **Infisical Cloud**) + SSH key to Storage Box + Borg CLI + `kubectl` access to the (running) cluster

**Steps:**

1. **Extract the Forge archive:**
   ```bash
   export BORG_REPO="u604953-sub2@u604953.your-storagebox.de:./forge"
   export BORG_RSH="ssh -i ~/.ssh/haven_ed25519 -p 23"
   export BORG_PASSPHRASE="<strata values get BORG_PASSPHRASE_FORGE>"

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

> **The k3s datastore snapshot (`opt/haven/var/backup/forge/datastore/`) is NOT part of this procedure on purpose.** It's a fast, same-cluster-corruption recovery shortcut (restore etcd/SQLite in place on the *same* cluster identity), not a mechanism for rebuilding a *different* cluster after total loss — see [Option 3](#option-3-full-disaster-recovery-all-tiers) for why the git-committed Helm/module configs are the real recovery path in that case.

**Restore testing:** Included in the monthly restore drill above — restore each Postgres dump + one PVC tar to a temporary namespace and verify data integrity.

### Option 2: Restore kSuite Email/Calendar/Contacts

**When to use:** A family member accidentally deleted email/calendar events/contacts past kSuite's own trash retention, or the account itself needs restoring after a compromise

**Prerequisites:** Borg passphrase (`BORG_PASSPHRASE_HEARTH` in Infisical Cloud) + SSH key to Storage Box + Borg CLI

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

**Scenario:** Total loss of both Hearth and Forge — worst case, both Storage Boxes destroyed too.

**Recovery window:** ~4 hours

**Why this is actually recoverable:** nothing required below lives *only* on the destroyed VPS. The Borg passphrases are in Infisical Cloud, the Storage Box account credentials are in Infisical Cloud, the SSH keypair used to reach the Storage Box is regenerated fresh by `hearth-init.yml`/`forge-init.yml` and re-authorized against the *existing* Storage Box account automatically, and every Helm/module config Forge needs is committed to this git repo. See design.md's *"Cloud-first bootstrap"* principle.

**Step-by-step:**

1. **Rebuild infrastructure.** Run `deploy-infra.yml` → `deploy-hearth-init.yml` → `deploy-forge-init.yml`. Both `*-init.yml` playbooks generate a fresh Borg SSH keypair and automatically re-authorize it against your existing Storage Box sub-account (using the Storage Box password from Infisical) — you do not need to recover an old private key.

2. **If the Storage Box itself was also destroyed** (not just the VPS): order a replacement box, then `rclone sync` the latest copy back down from kDrive (Tier 2) before continuing — kDrive's 30-day version history is what makes the Storage Box itself disposable.

3. **Restore Hearth** — this is just [Option 1](#option-1-restore-from-borg-hearthforge-system-state) end to end:
   ```bash
   export BORG_PASSPHRASE="<strata values get BORG_PASSPHRASE_HEARTH>"
   borg extract $BORG_REPO::hearth-<latest>
   docker compose up -d
   ```
   This alone restores Authentik, Vaultwarden, and the kSuite email/calendar/contacts mirror.

4. **Restore Forge — recreate first, then restore data, in that order:**
   ```bash
   strata deploy run --scope apps --stage applications_forge
   ```
   This recreates every namespace, Helm release, Postgres pod, and PVC **fresh from this repo's own committed config** — the actual source of truth for Forge's desired state, not the k3s datastore snapshot. Only *after* this succeeds, follow [Option 1b](#option-1b-restore-forge-postgres-databases--app-config-immich-nextcloud-jellyfin-kavita-gatus) to restore the Postgres dumps and PVC tars into the now-existing (but empty) resources.

5. **Immich's photos and the Nextcloud/Kavita/Jellyfin documents tree need no restore action at all** — that data was never inside a Borg archive. It lives directly on the `haven-data` Storage Box (SMB `hostPath` mount), independent of both VPS's lifecycle; Forge simply re-mounts the same paths once it's back up.

6. **Test:** Verify Authentik login, Vaultwarden unlock, Immich photos visible, Jellyfin library scan, and (if applicable) that the kSuite mirror directory is present under `/opt/haven/var/backup/ksuite/`.

---

## Monitoring & Alerts

Each job below pings a **distinct** Healthchecks.io check (`HEALTHCHECK_PING_KSUITE`, `HEALTHCHECK_PING_HEARTH`, `HEALTHCHECK_PING_FORGE` — see [Secrets & Credentials](#secrets--credentials)). Configure each check in **Cron** schedule mode (not "Simple"), using the exact cron expression below in UTC — this lets Healthchecks.io flag a run that's late *relative to its own schedule*, rather than just "no ping in the last N hours" (which is a much weaker signal for jobs sequenced this tightly, 30 minutes apart).

| Job                    | Trigger     | Cron (UTC)   | Suggested grace period | Why                                                                                                                                                                                                                     |
| ---------------------- | ----------- | ------------ | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| kSuite backup (Hearth) | On-VPS cron | `30 1 * * *` | 25 min                 | Must finish before Hearth's Borg run at 02:00 UTC so Borg archives a complete mirror, not one mid-sync — a grace period longer than the 30-minute gap to the next job would defeat that ordering guarantee              |
| Borg backup (Hearth)   | On-VPS cron | `0 2 * * *`  | 60 min                 | Small dataset (Authentik/Vaultwarden/config/kSuite mirror) — generous headroom for `borg compact` as the repo grows, while still catching a genuinely stuck run same-morning                                            |
| Borg backup (Forge)    | On-VPS cron | `30 2 * * *` | 90 min                 | Does the most work of the three: SQLite datastore backup, two `pg_dumpall`s, dynamic PVC discovery + tar, then `borg create`/`prune`/`compact` — budget more time, especially as Immich/Nextcloud's Postgres data grows |

| Manual/periodic check | Tool          | Frequency | Alert             | Escalation                    |
| --------------------- | ------------- | --------- | ----------------- | ----------------------------- |
| Storage Box capacity  | Manual review | Monthly   | Alert at 80% full | Upgrade box tier (5/10/20 TB) |

> **Tier 2 (rclone → kDrive) has no Healthchecks.io check yet — because it has no cron job yet.** See [Limits & Known Issues](#limits--known-issues) below: this is documented as a design intent throughout this file but was never actually implemented. Don't configure a dead-man's switch for it until the job itself exists, or you'll just get permanent false alerts.
>
> **The GitHub Actions scheduled workflow that used to also run Hearth's Borg backup (`backup-haven.yml`) has been removed** — it duplicated the on-VPS cron above, running the identical script twice a day via two independent mechanisms. The on-VPS cron + its Healthchecks.io check is now the single source of truth for Hearth's backup.

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
