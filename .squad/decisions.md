# Squad Decisions

## Active Decisions

No decisions recorded yet.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction

## Decision History

### 2026-06-11: Prefer upstream strata reusable actions/workflow with pinned versions

**By:** Vincent Huybrechts (merged from Mal inbox)
**Decision:** When consuming strata GitHub Actions/workflows, use upstream references with explicit release tags and avoid floating refs in production.
**Rationale:** Reduces maintenance duplication while keeping deployments deterministic and reviewable.
**Source:** .squad/decisions/inbox/mal-strata-official-actions.md

### 2026-06-11: Merged decision inbox snapshot

**By:** Scribe (requested by Vincent Huybrechts)
**Decision:** Merge all current inbox items into decision history as append-only records.
**Rationale:** Preserve pending and adopted decisions in one canonical file while keeping source references.

**Merged Items:**

- **Source:** .squad/decisions/inbox/squad-update-safety-strategy.md
 **Summary:** Defer production update safety implementation until Wave 1 is stable; require pinned versions, pre-update backups, post-update health gates, rollback path, and staged upgrades.
- **Source:** .squad/decisions/inbox/mal-workflow-architecture.md
 **Summary:** Choose workflow ownership in haven (Option C); do not call strata reusable workflow directly; copy/adapt required composite actions.
- **Source:** .squad/decisions/inbox/mal-command-restructuring-2026-06-01.md
 **Summary:** Remove `strata diff`; separate concerns via `build plan`, new `deploy plan`, and new `env` command group.
- **Source:** .squad/decisions/inbox/kaylee-workflow-gaps.md
 **Summary:** Record identified workflow gaps versus strata v0.0.5 and prioritize required fixes, should-fix items, and architecture decisions.
- **Source:** .squad/decisions/inbox/kaylee-terraform-hearth.md
 **Summary:** Keep initial Hearth Terraform design choices (static rules, local state, no block volumes) with follow-up review questions.
- **Source:** .squad/decisions/inbox/kaylee-ansible-provisioner-2026-06-02.md
 **Summary:** Adopt Hearth Ansible provisioner/bootstrap path aligned with strata v0.0.6 capabilities.

**Completion Context (this session):**

- Strata upgraded from 0.3.0 to 0.4.0.
- Successful command: `uv tool install --force --refresh --default-index https://pypi.org/simple xyz-strata==0.4.0`
- Binary path confirmed: `C:\Users\vince\.local\bin\strata.exe`
- PATH resolution confirmed.
