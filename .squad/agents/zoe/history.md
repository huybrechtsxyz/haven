# Zoe — Project History

## Project Context (day-1 seed)

- **Project:** Haven — family IT platform for 5 users (Huybrechts family)
- **Owner:** Vincent Huybrechts
- **Migration plan:** Two-wave approach documented in `docs/design/hosting-guide.md`
  - Wave 1: Infra (Hetzner VPS + services) while Google Workspace stays active
  - Wave 2: Email/files/calendar cutover to Infomaniak kSuite
- **Wave 1 status (2026-05-29):** 🟡 In Progress
  - Phase 1.1 (domain transfer): 🟡 In Progress — transfers initiated 2026-05-27, steps 10-14 pending
  - Phase 1.2 (Hetzner VPS): 🔴 Not started
  - Phases 1.3-1.8: 🔴 Not started
- **Wave 2 status:** 🔴 Not started (blocked on Wave 1 soak gate)
- **strata validate invocation:** `& "e:\UserData\VHUYBREC\AppData\Roaming\uv\tools\xyz-strata\Scripts\strata.exe" validate <file>`
  - Note: `strata` not on PATH — use full path or add uv tools bin to PATH
  - apiVersion `strata.huybrechts.xyz/v1` is correct (schema update pending for platform.huybrechts.xyz/v1)
- **Key files to validate:** all `stack/*.yaml`, `deploy/*.yaml`, `envs/*.yaml`

## Learnings
