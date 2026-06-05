# Decision: Making Strata Actions Official — What Changes and What It Means for Haven

**Date:** 2026-05-31  
**Author:** Mal  
**Status:** Recommendation — for Vincent (strata owner) and Kaylee (haven implementation)

---

## Short Answer

Yes, it is worth doing. The fix is small. One change in strata unblocks everything — and it also
invalidates the reasoning behind our previous decision to copy the actions into haven.

---

## The Root Cause in Plain English

GitHub Actions resolves `uses: ./.github/actions/setup-strata` relative to the **calling** repo, not
the repo that owns the reusable workflow. So when haven calls
`huybrechtsxyz/strata/.github/workflows/deploy-workspace.yml`, GitHub tries to find
`.github/actions/setup-strata` in **haven's** repo. It's not there. The workflow breaks.

This is a GitHub limitation for reusable workflows: relative paths only work when you call your own
workflow. The fix is to use absolute paths inside `deploy-workspace.yml`.

---

## The Critical Fix (one file, three lines in strata)

In `deploy-workspace.yml`, change:

```yaml
# Before — breaks when called from any external repo
uses: ./.github/actions/setup-yq
uses: ./.github/actions/setup-strata
uses: ./.github/actions/verify-integrations
```

```yaml
# After — works from any repo, always
uses: huybrechtsxyz/strata/.github/actions/setup-yq@v0.0.5
uses: huybrechtsxyz/strata/.github/actions/setup-strata@v0.0.5
uses: huybrechtsxyz/strata/.github/actions/verify-integrations@v0.0.5
```

That is the entire required change. Nothing else is needed for the actions to be reusable.

---

## What "Official GitHub Action" Actually Means

There are two tiers, and they are independent.

### Tier 1 — Properly referenceable from any repo (already achievable)

Any composite action in a **public** repository is already usable from any workflow with:

```yaml
uses: owner/repo/path/to/action@ref
```

The three strata actions meet this bar today, as soon as the path fix is applied. No extra metadata
is required. Any repo — haven or otherwise — can use them individually.

### Tier 2 — GitHub Marketplace listing (optional, cosmetic, future)

GitHub Marketplace listing requires:
- A `branding:` block in each `action.yml` (an icon name from Feather icons + a colour)
- For standalone listing, the `action.yml` should ideally be at the repo root — or each action lives
  in its own dedicated repo (e.g., `huybrechtsxyz/setup-strata`)
- A meaningful `README.md` in the action directory
- A public GitHub release with a proper version tag

None of this is needed for actions to work. It is purely for discoverability and credibility in the
Marketplace catalogue. Worth adding `branding:` blocks as a cheap improvement (10 minutes), but it
does not change the runtime behaviour at all.

Current status of `branding:` in strata's actions: **none of the three have it yet.**

---

## Impact on Haven — This Reopens Our Previous Architecture Decision

The previous decision (`mal-workflow-architecture.md`) chose **Option C (own the workflow)** because:

> *"Relative action paths mean the 3 actions must live in haven anyway — there is no actual DRY benefit."*

That con disappears the moment strata applies the path fix.

If strata fixes `deploy-workspace.yml`, haven can do this instead:

```yaml
# In haven's .github/workflows/deploy.yml
jobs:
  deploy:
    uses: huybrechtsxyz/strata/.github/workflows/deploy-workspace.yml@v0.0.5
    with:
      deployment_file: config/deploy-haven-prd.yaml
      dry_run: false
    secrets:
      azure_client_secret: ${{ secrets.AZURE_CLIENT_SECRET }}
```

Haven would not need to copy or maintain **any** of the three composite actions. It calls one
reusable workflow, pins a version, done.

The individual actions can also be used standalone if haven ever needs only a subset:

```yaml
- name: Setup Strata
  uses: huybrechtsxyz/strata/.github/actions/setup-strata@v0.0.5
  with:
    python-version: "3.13"
```

**Recommendation for Kaylee:** Hold off on implementing Option C (copying the three actions into
haven) until Vincent confirms whether he will apply the path fix to strata. If he does, Option A
becomes the right choice — simpler, less to maintain. If he does not, Option C stands.

---

## Version Pinning Strategy

Strata currently has tags `v0.0.1` through `v0.0.5` (v0.0.5 tagged today). Here is what to
recommend:

| Reference     | Behaviour                       | Recommendation                                                       |
| ------------- | ------------------------------- | -------------------------------------------------------------------- |
| `@main`       | Always latest commit            | Never use in production. Fine for strata's own tests.                |
| `@v0.0.5`     | Pinned to exact release         | Safe for consumers. Use this in haven right now.                     |
| `@v0` (alias) | Moves with every v0.x.x release | Good for "stay current within v0". Vincent should create this alias. |
| `@v1` (alias) | Moves with every v1.x.x release | Future. Create when strata reaches v1.0.0.                           |

**What strata should do on every release:**
1. Tag the release commit with `vX.Y.Z` (already doing this)
2. Force-update the major alias tag: `git tag -f v0 && git push origin v0 --force`

This lets consumers use `@v0` for "stay on latest v0 without breaking" or `@v0.0.5` for strict
pinning. Both are valid; the right choice depends on trust and tolerance for change.

For haven right now: pin to `@v0.0.5`. Move to `@v0` once strata is stable.

---

## Concrete List of Changes to Propose Upstream (for Vincent)

These are ordered by value vs effort.

### Must do (unblocks everything)

1. **Fix relative paths in `deploy-workspace.yml`** — Replace the three relative `uses:` references
   with `huybrechtsxyz/strata/.github/actions/<name>@<tag>`. One file, three lines.

2. **Create a `v0` major-version alias tag** — So consumers can pin `@v0` instead of tracking
   every patch release. Run once after each release:
   ```bash
   git tag -f v0 v0.0.5
   git push origin v0 --force
   ```

### Should do (quality, discoverability)

3. **Add `branding:` to all three `action.yml` files** — Required for Marketplace listing, cheap to
   add. Example for `setup-strata`:
   ```yaml
   branding:
     icon: terminal
     color: blue
   ```
   Suggested icons: `setup-strata` → `terminal`, `setup-yq` → `file-text`, 
   `verify-integrations` → `check-circle`.

4. **Pin yq version in `setup-yq`** — The current implementation fetches `latest` from the GitHub
   API at runtime. This is fragile: a yq breaking release would silently break all consumers. Add a
   `yq-version` input with a pinned default.

5. **Add `README.md` to each action directory** — Documents inputs/outputs. Makes the action usable
   without reading the source.

### Nice to have (Marketplace path, low priority)

6. **Separate repos per action** — For Marketplace listing, GitHub requires the action's
   `action.yml` to be at the repo root. Options: create `huybrechtsxyz/setup-strata`,
   `huybrechtsxyz/setup-yq`, `huybrechtsxyz/verify-integrations`. Only worth doing if Marketplace
   discoverability is a goal.

---

## Summary

| Question                                 | Answer                                                                         |
| ---------------------------------------- | ------------------------------------------------------------------------------ |
| Is the fix worth doing?                  | Yes — one file, three line changes, unblocks full reuse                        |
| What does "official action" require?     | Tier 1 (just works): only the path fix. Tier 2 (Marketplace): also `branding:` |
| Does this change haven's architecture?   | Yes — Option A becomes viable and simpler if strata applies the fix            |
| What version should haven pin?           | `@v0.0.5` now, move to `@v0` once strata is stable                             |
| Total effort in strata to unblock haven? | 30 minutes (path fix + v0 alias tag)                                           |
