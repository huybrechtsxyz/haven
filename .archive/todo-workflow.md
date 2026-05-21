# TODO: strata sln init — no post-init workflow guidance

## Summary

After `strata sln init`, the "Next steps" output only lists bare CLI commands.
There is no explanation of *why* each step exists or what the overall workflow
looks like. A first-time user (or someone returning after a break) has no
mental model to follow.

## Current output (after init without template)

```
Next steps:
    1. Scaffold config files:  strata init --name <name> --template aks
    2. Register your repo:     strata repo add <name> <git-url> --clone
    3. Add a profile:          strata profile add prd --activate
```

Problems:
- No indication of the *concept* of a profile, a config ref, or an env ref
- No mention of the validate → build → deploy pipeline
- No link to docs or a getting-started guide
- Command list is template-conditional (blank init shows different steps than
  templated init), creating inconsistent first-run experiences

## Expected behaviour

`strata sln init` should emit (or link to) a concise **workflow overview**:

```
Workspace 'haven' is ready. Here is the standard workflow:

  CONFIGURE
    1. Add your configuration:  strata ref config add <name> --path <file>
    2. Add your environment:    strata ref env add <name> --path <file>
    3. Activate a profile:      strata profile add prd --activate

  DEVELOP
    4. Validate a file:         strata validate <file>
    5. Check workspace status:  strata sln status

  DEPLOY
    6. Build an artifact:       strata build run --file <deployment>
    7. Deploy:                  strata deploy run --file <deployment>

  See full docs: https://docs.strata.huybrechts.xyz/getting-started
```

Alternatively, a `strata help workflow` or `strata sln guide` command could
print this at any time, not just after init.

## Proposed issue (raise in strata repo)

**Title:** Post-init output should explain the configure → validate → deploy workflow

**Labels:** `enhancement`, `dx`, `init`, `onboarding`

**Body:**

> After `strata sln init`, new users see a list of CLI commands but no explanation
> of the conceptual workflow. They need to understand:
>
> - What a *profile* is and why they need one before anything else works
> - What *config refs* and *env refs* are and how they relate to deployment files
> - The validate → build → deploy sequence and when each step is needed
>
> **Proposed fix options (pick one or both):**
>
> 1. Expand the post-init "Next steps" block to include brief descriptions for
>    each step and group them into phases (Configure / Develop / Deploy).
> 2. Add a `strata sln guide` command (or extend `strata help`) that prints the
>    full workflow overview on demand.
>
> The output should always be accurate regardless of whether a template was used.

## Notes

- Discovered during haven workspace setup (2026-05-21).
- Related: `todo-init.md` (missing `.github/copilot-instructions.md` scaffold)
- Related: `todo-cmdline.md` (inconsistent `--file` / positional arg)
