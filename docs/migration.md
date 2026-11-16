# Haven Migration Guide

> Living workbook — track progress as you go. For system architecture and design rationale, see [design.md](design.md) and [architecture.md](architecture.md). For per-service setup, see [Nextcloud](services/nextcloud.md), [Kavita](services/kavita.md), [Jellyfin](services/jellyfin.md).

---

## Google Drive → Nextcloud / Kavita / Jellyfin data migration

**Status:** 🟡 Planning — infrastructure ready, data transfer not started
**Source:** Google Workspace shared Drive (~1000 GB total, 5 family members)
**Destination:** `haven-data` Storage Box `docs` sub-account, mounted at `/mnt/haven-data-docs` on Forge, browsable via Nextcloud's External Storage and read by Kavita/Jellyfin

### Prerequisites (all complete)

- [x] `/mnt/haven-data-docs` CIFS-mounted on the Forge host (`nounix`, `file_mode=0777`, `dir_mode=0777` — see [Forge's development notes](guides/forge.md#development-notes) for the Unix Extensions gotcha)
- [x] Nextcloud External Storage entries registered: **Haven** (root), **Media**, **Books**
- [x] Full folder tree created: `archive/`, `documents/`, `family/`, `games/`, `media/`, `projects/`, `shared/`, `software/`, `templates/`, `uploading/`, `books/{comics,manga,general,fiction}/`
- [x] Kavita libraries created: **Comics**, **Manga**, **Fiction**, **General**
- [x] End-to-end upload path confirmed (Nextcloud upload → Storage Box → Kavita library scan, 2026-08-30)

### Folder mapping

| Google Drive folder                                            | Destination                                                                 | Notes                                                                                                                                                                                                                                                             |
| -------------------------------------------------------------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Archive                                                        | `archive/`                                                                  |                                                                                                                                                                                                                                                                   |
| Books/comics                                                   | `books/comics/`                                                             | Kavita library: Comics                                                                                                                                                                                                                                            |
| Books/manga                                                    | `books/manga/`                                                              | Kavita library: Manga                                                                                                                                                                                                                                             |
| Books/fiction                                                  | `books/fiction/`                                                            | Kavita library: Fiction                                                                                                                                                                                                                                           |
| Books/technology, references, manuals, management, non-fiction | `books/general/`                                                            | Consolidated into one Kavita library: General                                                                                                                                                                                                                     |
| Documents                                                      | `documents/`                                                                |                                                                                                                                                                                                                                                                   |
| Family/<per person>                                            | `family/<person>/`                                                          | ⚠ **Pending decision** — actual per-person folder names not yet chosen                                                                                                                                                                                            |
| Games                                                          | `games/`                                                                    |                                                                                                                                                                                                                                                                   |
| Media                                                          | `media/`                                                                    | ⚠ Confirm contents are actually movies/shows/music before copying (Jellyfin libraries expect `movies/`, `shows/`, `music/` subfolders)                                                                                                                            |
| Photos                                                         | *(excluded — Immich's separate migration path, not part of this docs tree)* |                                                                                                                                                                                                                                                                   |
| Projects                                                       | `projects/`                                                                 |                                                                                                                                                                                                                                                                   |
| Shared                                                         | `shared/`                                                                   | ⚠ **Pending decision** — old Drive sharing likely included people outside the 5-person family; the new setup is members-only (Authentik-gated). Decide whether to use Nextcloud public links for anything that needs external access before migrating this folder |
| Software                                                       | `software/`                                                                 |                                                                                                                                                                                                                                                                   |
| Templates                                                      | `templates/`                                                                |                                                                                                                                                                                                                                                                   |
| Uploading                                                      | `uploading/`                                                                |                                                                                                                                                                                                                                                                   |

### Migration method

At ~1000 GB, routing the transfer through Nextcloud's own PHP-mediated file operations (Option A below) risks timeouts and is unreasonably slow. **Chosen approach: Option B (rclone via a one-off Kubernetes Job)**, writing directly to the same hostPath Nextcloud/Kavita/Jellyfin already use — bypassing Nextcloud's API entirely.

<details>
<summary>Option A — Nextcloud's own Google Drive External Storage (considered, not chosen)</summary>

Mount Google Drive as a second Nextcloud External Storage entry (Settings → Administration → External Storage → Add storage → Google Drive, OAuth via a Google Cloud OAuth Client ID/Secret), then use the Files app's "Move or copy" to transfer server-side between the two mounts. Simple, no new infra, but not robust at this data volume.
</details>

**Option B — rclone as a one-off Kubernetes Job (chosen)**

Since this is a **Google Workspace** (not personal Gmail accounts), use a **service account with domain-wide delegation** rather than per-user OAuth — one key can impersonate any of the 5 family members and pull their Drive contents directly.

#### Step 1 — Google Workspace admin setup (manual, Vincent's admin access required)

1. **Google Cloud Console** → create a service account in the Workspace's GCP project → generate a JSON key.
2. **Google Admin Console** → Security → API Controls → Domain-wide Delegation → add the service account's **Client ID**, authorize scope:
   ```
   https://www.googleapis.com/auth/drive.readonly
   ```
   (read-only — this is a one-way copy out, not a sync)

**Status:** ⬜ Not started

#### Step 2 — rclone config

Once the service account key exists, configure rclone with `service_account_file` + `--drive-impersonate <person>@domain` per family member. No individual per-user OAuth consent needed.

**Status:** ⬜ Not started — blocked on Step 1

#### Step 3 — Kubernetes Job

One-off Job/Pod using an rclone image, mounting the same hostPath `/mnt/haven-data-docs` Nextcloud uses (`extraVolumes`/`extraVolumeMounts` in [config/forge/modules/nextcloud.yaml](../config/forge/modules/nextcloud.yaml)), running `rclone copy` per folder mapping above.

**Status:** ⬜ Not started — blocked on Steps 1–2

#### Step 4 — Post-transfer verification

- [ ] `occ files:scan --all` in Nextcloud to pick up new content in the filecache
- [ ] Trigger Kavita library scans (Comics, Manga, Fiction, General) — confirm content appears
- [ ] Trigger Jellyfin library scan — confirm `media/movies|shows|music` content appears
- [ ] Spot-check file integrity/completeness on a sample of folders before considering the source Drive folder safe to archive

### Pending decisions (block `family/` and `shared/` migration specifically)

1. **`family/<person>` naming** — what are the actual per-person subfolder names?
2. **`shared/` external access** — does anything in the old Drive's "Shared" folder need to remain accessible to people outside the 5-person household? If so, plan Nextcloud public-link sharing (with expiry) for those specific items before migrating.

---

## Prior migration (Wave 1/Wave 2 — Kamatera → Hetzner, Google Workspace → kSuite)

See `.archive/v1/docs/migration.md` for the historical domain-transfer and infrastructure-cutover record from the original two-wave migration plan (Kamatera VPS decommission, domain transfers to INWX, Bitwarden Team → Vaultwarden). That migration is complete; this document now tracks the **data migration** phase (Google Drive → self-hosted apps) described above.
