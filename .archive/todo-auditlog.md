# TODO: strata audit log — hardcoded path and no date-based rotation

## Summary

The audit log is fully hardcoded in `base_command.py`:

```python
audit_path = self._work_path / ".strata" / "audit.log"
configure_audit_log(log_path=str(audit_path))
```

`configure_audit_log()` itself also hardcodes rotation strategy:
- Handler: `RotatingFileHandler` (size-based, 5 MB / 3 backups)
- No date suffix — rotated files are `audit.log.1`, `audit.log.2`, …
- No way to redirect output (e.g. `/var/log/haven/audit.log`)
- Not configurable from `logging.yaml` or any workspace config

For a production server like haven this is insufficient:
- Logs should land in `/var/log/haven/` alongside the application log
- Daily rotation with `yyyymmdd` suffixes makes log archiving and scraping
  (Promtail/Alloy → Loki) trivial
- Backup retention should be configurable per environment

## Expected behaviour

`configure_audit_log()` should support (at minimum):

| Parameter      | Default             | Notes                           |
| -------------- | ------------------- | ------------------------------- |
| `log_path`     | `.strata/audit.log` | Override to any absolute path   |
| `rotation`     | `size`              | `size` or `daily`               |
| `max_bytes`    | 5 MB                | Used when `rotation=size`       |
| `backup_count` | 3                   | Number of rotated files to keep |
| `date_suffix`  | `%Y%m%d`            | Used when `rotation=daily`      |

When `rotation=daily`, use `TimedRotatingFileHandler(when="midnight", ...)` which
automatically appends a date suffix (`audit.log.20260521`).

## Proposed configuration (in logging.yaml)

Add an optional `audit:` section to the logging YAML, parallel to the existing
`azure:` extension pattern already in the loader:

```yaml
audit:
  path: /var/log/haven/audit.log
  rotation: daily          # size | daily
  backup_count: 30         # 30 days retention
  date_suffix: "%Y%m%d"
```

`_configure_from_yaml()` in `logger.py` would extract and apply this section
before calling `dictConfig`, similar to how the `azure:` block is handled today.

`base_command.py` would then pass the audit config from the loaded YAML instead
of hardcoding the path.

## Proposed issue (raise in strata repo)

**Title:** Audit log path and rotation strategy should be configurable

**Labels:** `enhancement`, `logging`, `dx`, `audit`

**Body:**

> The audit log is hardcoded to `.strata/audit.log` with size-based rotation
> (5 MB / 3 backups). There is no way to override the output path or switch to
> daily rotation with date suffixes.
>
> **Requested changes:**
>
> 1. Add an `audit:` section to the `logging.yaml` dictConfig extension (same
>    pattern as the existing `azure:` section).
> 2. Support `rotation: daily` via `TimedRotatingFileHandler` so rotated files
>    get `yyyymmdd` suffixes — compatible with Promtail/Loki scraping.
> 3. Make `base_command.py` read audit config from the loaded logging YAML
>    rather than hardcoding path and defaults.

## Notes

- Discovered during haven workspace setup (2026-05-21).
- Haven target path: `/var/log/haven/audit.log`, daily rotation, 30-day retention.
- Related: `todo-init.md` — logging.yaml is not scaffolded by `sln init` either.
