# Feature Request: Grouped CLI Help + New Command Groups

**Product:** Strata CLI  
**Version tested:** v0.0.4  
**Requested by:** haven platform team  
**Date:** 2026-05-31  
**Priority:** Medium  

---

## Summary

Three related requests submitted together because they share the same motivation:
**a DevOps engineer should be able to scan `strata --help` and immediately understand the workflow**,
without memorising 17+ command names or consulting documentation.

1. **Group commands in `--help` output** — visually separate commands by workflow stage
2. **`strata env`** — new subcommand group for runtime/deployed-environment inspection
3. **`strata doctor`** — new top-level command for health checks and compliance audit
4. **`strata upgrade`** — new top-level command for CLI self-update

---

## Part 1 — Grouped `--help` Output

### Problem

`strata --help` currently outputs a flat alphabetical list of 17 commands:

```
Commands:
  build     Build platform and Terraform artifacts.
  config    Manage workspace CLI preferences and logging configuration.
  deploy    Deploy platform using provisioners.
  diff      Show what would change in the environment before deploying.
  help      Show help topics and workflow guidance.
  log       Show execution logs for the current workspace.
  new       Create a new platform configuration file from a template.
  profile   Manage profiles in the current solution.
  ref       Manage file references (env, config, data, secret) within...
  repo      Manage repositories in the current solution.
  schema    Inspect JSON schemas for platform YAML document kinds.
  sln       Manage the solution workspace lifecycle.
  tools     Manage and inspect external tool integrations.
  validate  Validate a platform YAML file against its kind-specific schema.
  values    Inspect and manage deployment values (variables, secrets,...
  vars      Manage team-shared template variables (stored in solution.json).
  version   Show CLI version.
```

A new user sees no structure. `build` and `config` look equally important.
There is no signal about which commands to use first, or in what order.

### Proposed Output

Group commands under labelled sections. Click supports this natively via
`CommandCollection` with section labels, or a custom `HelpFormatter`.

```
Usage: strata [OPTIONS] COMMAND [ARGS]...

  Strata CLI — automates workspace preparation, configuration, and deployment.

Options:
  -h, --help  Show this message and exit.

Workspace Setup:
  sln       Manage solution workspace lifecycle (init, update, export, clean).
  profile   Manage profiles within the current solution.
  new       Create a new platform configuration file from a template.

Configuration:
  config    Manage workspace CLI preferences and logging settings.
  ref       Manage file references (env, config, data, secret).
  repo      Manage repositories in the current solution.
  vars      Manage team-shared template variables (stored in solution.json).
  values    Inspect and manage deployment values (variables, secrets).

Build & Deploy:
  build     Build platform and Terraform artifacts.
  diff      Preview what would change before deploying.
  deploy    Deploy platform using provisioners.

Inspect & Validate:
  validate  Validate a platform YAML file against its schema.
  schema    Inspect JSON schemas for platform YAML document kinds.
  tools     Manage and inspect external tool integrations.
  env       Inspect the deployed environment (status, outputs, state, graph).
  doctor    Run health checks and compliance diagnostics.
  log       Show execution logs for the current workspace.

Utility:
  upgrade   Upgrade the Strata CLI to the latest version.
  version   Show CLI version.
  help      Show help topics and workflow guidance.
```

### Why This Matters

- **Onboarding:** A new team member reads top-to-bottom: setup → configure → build → deploy → inspect.
- **Day-to-day:** A DevOps engineer scanning for "what do I run to see outputs?" lands directly on *Inspect & Validate*.
- **No breaking change:** Command names, flags, and behaviour are unchanged. This is purely cosmetic.

### Implementation Note

Click's `Group` class accepts a `result_callback` and supports custom formatters.
The grouping can be implemented via a `CommandSectionGroup` wrapper that assigns
each command a `section` attribute and renders sections in order.
Alternatively, `rich-click` (already a popular Click extension) supports this out of the box
via `OPTION_GROUPS` / `COMMAND_GROUPS` configuration.

---

## Part 2 — `strata env` (New Subcommand Group)

### Problem

There is currently no way to inspect the **live deployed environment** from the CLI.
Users must drop into raw `tofu`/`terraform` commands or read state files manually.
This breaks the strata abstraction — you use strata to deploy, but not to observe.

### Proposed Commands

```
strata env status    Show the current state of the deployed environment.
strata env output    Show outputs from the last successful deployment.
strata env state     Inspect raw provisioner state (read-only tofu state show).
strata env graph     Show the dependency graph of platform components.
strata env lock      Lock remote state to prevent concurrent operations.
strata env unlock    Unlock remote state (with force option for stuck locks).
```

#### `strata env status`

Shows the high-level deployment health across all workspaces in the solution.

```
$ strata env status

  🔌  Environment: haven / prd
  📦  Provisioner: haven_iac (terraform / Terraform Cloud)
  🏢  Backend: huybrechts-xyz / haven_deploy_prd

  Resources:
    ✔  hcloud_network.platform_network     (unchanged)
    ✔  hcloud_server.hearth                (unchanged)
    ✔  hcloud_server.forge                 (unchanged)
    ✔  hcloud_ssh_key.platform_key         (unchanged)

  Last apply:  2026-05-28 14:32:11 UTC  (3 days ago)
  State:       clean — no drift detected
```

Options:
- `--drift` — explicitly run a plan to detect drift (implies `tofu plan`)
- `--output [console|json]`

#### `strata env output`

Shows outputs from the last apply. Thin wrapper around `tofu output`.

```
$ strata env output

  hearth_public_ip    →  65.21.xxx.xxx
  hearth_public_ipv6  →  2a01:4f9::xxx
  hearth_private_ip   →  10.0.1.1
  hearth_server_id    →  12345678
  network_id          →  87654321
  network_cidr        →  10.0.0.0/16
```

Options:
- `--name NAME` — show a single output value (useful for scripting)
- `--json` — raw JSON output
- `--raw` — raw value only, no labels (for use in shell scripts: `$(strata env output --name hearth_public_ip --raw)`)

#### `strata env state`

Read-only inspection of provisioner state. Wraps `tofu state list` and `tofu state show`.

```
$ strata env state list
  hcloud_network.platform_network
  hcloud_server.hearth
  hcloud_server.forge
  hcloud_ssh_key.platform_key

$ strata env state show hcloud_server.hearth
  # hcloud_server.hearth:
  resource "hcloud_server" "hearth" {
      id         = "12345678"
      name       = "hearth"
      server_type = "cx22"
      ...
  }
```

**No write operations.** State modification (mv, rm, import) is explicitly out of scope
for this request — those are destructive and belong in a separate, more carefully
gated feature.

#### `strata env graph`

Renders the dependency graph of platform components. Sources from workspace + provisioner.

```
$ strata env graph

  haven_iac (terraform)
  ├── hcloud_network.platform_network
  ├── hcloud_ssh_key.platform_key
  ├── hcloud_server.hearth
  │     depends_on: platform_network, platform_key
  └── hcloud_server.forge
        depends_on: platform_network, platform_key, hearth

$ strata env graph --format dot    # Graphviz DOT — pipe to dot -Tsvg
$ strata env graph --format mermaid  # Mermaid — paste into docs/draw.io
```

#### `strata env lock` / `strata env unlock`

Wraps Terraform Cloud / OpenTofu remote state locking.

```
$ strata env lock --reason "manual maintenance window"
  ✔  State locked: haven_deploy_prd
  Lock ID: abc-123-def

$ strata env unlock
  ✔  State unlocked: haven_deploy_prd

$ strata env unlock --force --lock-id abc-123-def
  ⚠  Force-unlocking state: haven_deploy_prd
  ✔  Done.
```

---

## Part 3 — `strata doctor` (Health Check + Compliance Audit)

### Problem

Two related needs currently have no home in the CLI:

1. **Health check** — "is my strata workspace correctly configured end-to-end?" before running CI.
   `strata tools status` shows integration availability but not workspace config health.
   `strata sln status` shows workspace structure but not integration readiness.
   Neither combines both into an actionable pre-flight check.

2. **Compliance audit** — "give me an audit trail of who deployed what and when."
   Required for NIS2 and ISAE3402 compliance. Currently not captured by strata at all.

### Proposed Commands

```
strata doctor           Run a full health check across workspace + integrations.
strata doctor audit     Show the compliance audit trail for deployments.
```

#### `strata doctor`

Modelled after `npm doctor`, `brew doctor`, `gh doctor`. Single command that checks everything
and tells you exactly what to fix.

```
$ strata doctor

  🩺  Strata Doctor — haven / prd

  Workspace:
    ✔  solution.json         valid
    ✔  config/cfg-haven.yaml valid (schema OK)
    ✔  Active profile: prd
    ✔  Config file resolves: config/cfg-haven.yaml

  Integrations:
    ✔  git          2.45.1    (required >= 2.30.0)
    ✔  tofu         1.8.0     (required >= 1.6.0)
    ✔  ansible      2.16.3    (required >= 2.14.0)
    ✗  infisical    not found (optional — set INFISICAL_ESO_TOKEN or install CLI)

  Provisioner connectivity:
    ✔  Terraform Cloud reachable (huybrechts-xyz)
    ✔  Workspace haven_deploy_prd exists and is accessible
    ✔  TF_TOKEN_app_terraform_io is set

  Secrets resolution:
    ✔  HETZNER_API_TOKEN     set (store: environment)
    ✔  HETZNER_PUBLIC_KEY    set (store: environment)
    ✔  HETZNER_PRIVATE_KEY   set (store: environment)
    ✗  HETZNER_ROOT_PASSWORD not set ← will cause deploy failure

  Result: 1 error, 1 warning — run `strata doctor --fix` for remediation hints
```

Options:
- `--fix` — don't auto-fix, but print remediation steps for each failure
- `--output [console|json]` — JSON output for CI integration (exit code 1 on errors)
- `--workspace NAME` — scope to a single workspace

**CI pattern:**
```yaml
- name: Pre-flight check
  run: strata doctor --output json
  # exits 1 if any required check fails — fails the pipeline early
```

#### `strata doctor audit`

Compliance audit trail. Reads from strata execution logs and provisioner run history.

```
$ strata doctor audit

  📋  Audit Trail — haven / prd (last 30 days)

  2026-05-28 14:32:11 UTC  deploy   ✔ success   vhuybrechts  strata v0.0.4  git:abc1234
  2026-05-25 09:14:03 UTC  deploy   ✗ failed    vhuybrechts  strata v0.0.4  git:def5678
  2026-05-21 11:18:44 UTC  deploy   ✔ success   vhuybrechts  strata v0.0.3  git:ghi9012
```

Columns: timestamp, command, result, operator (git config user.name), strata version, git commit.

Options:
- `--days N` — time window (default: 30)
- `--output [console|json|csv]` — CSV for export to compliance tooling
- `--workspace NAME` — scope to a single workspace

**NIS2 / ISAE3402 relevance:** The audit trail must record:
- Who ran the operation (operator identity)
- What was deployed (git commit + strata version)
- When (UTC timestamp)
- Whether it succeeded or failed

This gives change management evidence without requiring a separate ITSM integration.

---

## Part 4 — `strata upgrade` (CLI Self-Update)

### Problem

`strata sln update` updates package-owned workspace files after a strata version change.
There is no equivalent command to upgrade the **strata CLI binary itself**.
Users must remember the install invocation (`uv tool install --reinstall ...`) — not discoverable.

### Proposed Command

```
$ strata upgrade

  Current version:  v0.0.4
  Latest version:   v0.0.5

  Changes in v0.0.5:
    - Fix: build/deploy path contract for terraform provisioners
    - Feature: strata env subcommand group
    - Feature: strata doctor

  Upgrade? [Y/n]: y

  ✔  Upgraded strata from v0.0.4 → v0.0.5
  ℹ  Run `strata sln update` to apply any workspace template changes.
```

Options:
- `--yes` / `-y` — skip confirmation prompt (for CI/scripts)
- `--check` — check for updates without installing
- `--version VERSION` — install a specific version (for rollback)

**Implementation note:** strata is distributed via `uv tool install`. The upgrade command
should call `uv tool upgrade strata` (or `uv tool install --reinstall strata==VERSION`).
If uv is not available, fall back to `pip install --upgrade strata` and print a note.

---

## Acceptance Criteria Summary

| Feature | Acceptance Criteria |
|---------|-------------------|
| Grouped help | `strata --help` shows 5 labelled sections; all existing commands visible; no command removed or renamed |
| `strata env status` | Shows resource list + last apply time + drift indicator |
| `strata env output` | Shows all tofu outputs; `--name` + `--raw` flags work for scripting |
| `strata env state` | `list` and `show` work; no write operations exposed |
| `strata env graph` | Default ASCII tree; `--format dot` and `--format mermaid` produce valid output |
| `strata env lock/unlock` | Lock/unlock remote state; `--force` requires explicit `--lock-id` |
| `strata doctor` | Checks workspace + integrations + connectivity + secrets; exits 1 on errors; `--output json` works |
| `strata doctor audit` | Reads execution log; shows operator, version, commit, timestamp, result; `--output csv` works |
| `strata upgrade` | Detects current vs latest; upgrades via uv; `--check` flag; `--yes` for CI |

---

## Out of Scope (Separate Requests)

- `strata env state mv / rm / import` — destructive state operations (separate, gated feature)
- `strata whoami` — covered by `strata sln status`; no new command needed; doc note sufficient
- `strata lock` as top-level — intentionally nested under `strata env lock` to avoid accidental invocation
