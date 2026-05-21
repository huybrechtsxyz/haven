# TODO: strata — no "self" repository concept for single-repo workspaces

## Summary

`WorkspaceIacModel.source` uses `SourceModel`, which requires a `repository`
field that maps to a named entry in `configuration.spec.repositories`. In a
single-repo workspace (no external repos registered), there is no valid value
to put here for the workspace's own terraform code.

Haven's workspace file currently has:

```yaml
provisioners:
  - name: haven_iac
    provisioner: terraform
    source:
      repository: haven       # ← no repo named "haven" registered
      source_path: terraform
```

This passes Phase 1 validation (structural) but will fail Phase 2 (deep)
when strata tries to resolve `haven` against an empty repo_map.

## Options

1. **`repository: "."` or `repository: self`** — strata treats a special
   sentinel as "the current workspace root", bypassing repo_map lookup.
2. **`source_path` only (no repository)** — make `repository` optional in
   `SourceModel`; if absent, resolve relative to work_path.
3. **Register a bundled repo** — add a `bundled` type repo entry in
   `configuration.spec.repositories` pointing to `.` (workspace root). This
   works today but is boilerplate that single-repo users shouldn't need.

Option 2 is the cleanest for single-repo use cases; option 1 is an easy
short-term fix.

## Proposed issue (raise in strata repo)

**Title:** `SourceModel.repository` should be optional for single-repo workspaces

**Labels:** `enhancement`, `single-repo`, `dx`

**Body:**

> In a single-repo workspace, the IaC provisioner source lives in the workspace
> itself. `SourceModel` currently requires a `repository` field, forcing users
> to either register a dummy repo or leave an invalid reference.
>
> **Proposed fix:** make `repository` optional in `SourceModel`. When absent,
> resolve `source_path` relative to `work_path`. No `repo_map` lookup is
> performed.

## Notes

- Discovered during haven workspace setup (2026-05-21).
- Related: `todo-platformapiversion.md` — repos also embed the old API version.
- Workaround for now: leave `repository: haven` in place; Phase 1 passes,
  defer Phase 2 deep validation until the fix lands.
