# Restore Pipeline — Design Notes

## Decision: Separate restore workflow (not a deploy flag)

A restore is destructive (overwrites all data). It belongs in a dedicated
`restore.yml` workflow, not as a checkbox inside the deploy pipeline.

### Reasons

- **Safety** — no risk of accidentally triggering a restore during a normal deploy
- **Mental model** — deploy = push code/config; restore = disaster recovery; different risk profiles, different checklists
- **Cleaner confirmation** — the confirmation input is the first and only thing you see, with an explicit "THIS WILL OVERWRITE ALL DATA" description
- **Audit trail** — restore runs are clearly distinct from deploy runs in the Actions history, which matters when diagnosing incidents

### Cost / follow-up work

The Hetzner firewall SSH plumbing (get runner IP, get server IP, get firewall ID,
open/close temporary SSH rule) is currently duplicated inline in `deploy.yml`.
Extract it into a composite action under `.github/actions/` so both workflows
can share it.

---

## Restore workflow design

### GitHub Actions (`restore.yml`)

Inputs:
- `restore_confirm` (string, required) — must equal `RESTORE` exactly; validated as the first step, fails immediately otherwise
- `restore_archive` (string, optional) — Borg archive name; leave empty to use the latest archive automatically

Steps follow the same firewall-open / SSH-key-install / firewall-close pattern as `deploy.yml`.

### Ansible restore playbook (`hearth-restore.yml`)

Inserted sequence (runs before containers start):

1. Stop all containers — `docker compose down` (required: postgres holds file locks)
2. Resolve archive — if `restore_archive` is empty, run `borg list --last 1` to get the latest archive name
3. Run `borg extract` from `/` as root (root required because postgres data dirs are root-owned)
4. Hand off to normal startup: `docker compose pull` → `docker compose up -d`

### Prerequisites

`hearth-config` must have already run on the target server before restore is
attempted — it writes `/opt/haven/.borg_passphrase` and the SSH key needed to
reach the Storage Box. The restore playbook does not re-initialise those.

### Sequence on a wiped server

```
run_init    → hearth-init.yml     (SSH key, packages, borg repo check)
run_config  → hearth-config.yml   (passphrase file, cron, .env scaffold)
restore     → hearth-restore.yml  (borg extract → overwrite data dirs)
startup     →                     (docker compose up -d, already in restore playbook)
```
