### 2026-06-01: strata command restructuring — diff, build plan, deploy plan, env group
**By:** Vincent Huybrechts
**What:**
- Remove `strata diff` (duplicate of `build plan` with different formatting)
- `strata build plan` → artifact diff only (layer 1); `--artifacts-only` becomes default behavior
- Add `strata deploy plan` → terraform plan against live state (replaces diff layer 2)
- Add `strata env` group with: `env output` (tofu output), `env state list`, `env state show <resource>`
- Deprecate `strata deploy status` → replaced by `env output` (live) + `deploy plan` (plan view)
**Why:** Clean separation of build concern (artifact diff) vs deploy concern (terraform plan) vs env inspection (read-only state). `diff` was a redundant alias with no unique value.
**Related:** strata #62 (parent), strata #59 (superseded by env output)
