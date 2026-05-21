# TODO: strata sln init — missing .github/copilot-instructions.md scaffold

## Summary

After running `strata sln init --name <name>`, the workspace is correctly bootstrapped
(`.strata/` state dir, `solution.json`, `<name>.code-workspace`) but no `.github/`
folder is created. As a result there is no `copilot-instructions.md` file to give
GitHub Copilot context about the workspace, the stack, and how to use strata.

## Expected behaviour

`strata sln init` (or a first-party template) should scaffold `.github/copilot-instructions.md`
with at minimum:

- A one-liner description of the solution (name, purpose)
- Pointer to strata CLI and docs
- The active provider / stack type (if known from a template)
- Suggested day-to-day strata commands (`validate`, `build`, `deploy`, `sln status`)

The file should use `${solution_name}` substitution so it is personalised.

## Proposed issue (raise in strata repo)

**Title:** `sln init` should scaffold `.github/copilot-instructions.md`

**Labels:** `enhancement`, `dx`, `init`

**Body:**

> When initialising a new workspace with `strata sln init --name <name>`, a
> `.github/copilot-instructions.md` file should be created so that GitHub Copilot
> (and other AI assistants) immediately understand the workspace context.
>
> The file can be minimal by default and overridden/extended by templates.
>
> Minimum content:
> ```markdown
> # Copilot Instructions — ${solution_name}
>
> Workspace managed by [strata](https://docs.strata.huybrechts.xyz).
>
> ## Stack
> <!-- fill in: Docker Swarm / AKS / bare-metal / etc. -->
>
> ## Day-to-day commands
> - `strata sln status`          — workspace overview
> - `strata validate run -f ...` — lint & validate
> - `strata build run -f ...`    — build artifact
> - `strata deploy run -f ...`   — provision & deploy
> ```
>
> Templates can ship a richer version of this file (e.g. the `swarm` template
> would include Docker Swarm-specific guidance).

## Notes

- Discovered during haven workspace setup (2026-05-21).
- Currently the `.github/workflows/` folder is also absent; a follow-up issue
  should cover CI pipeline scaffolding for a strata-managed repo.
