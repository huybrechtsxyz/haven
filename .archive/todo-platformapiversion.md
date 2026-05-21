# TODO: API version string should be `strata.huybrechts.xyz/v1`

## Summary

Every strata YAML file uses:

```yaml
apiVersion: platform.huybrechts.xyz/v1
```

This should be:

```yaml
apiVersion: strata.huybrechts.xyz/v1
```

The product is called **strata**, not "platform". The domain `platform.huybrechts.xyz`
is generic and misleading — it does not reflect the CLI tool name, the package
name (`xyz-strata`), or the documentation URL (`docs.strata.huybrechts.xyz`).

## Scope of change in strata repo

The value is defined in a single enum, but the blast radius is wide:

| Location                                              | Change needed                                                 |
| ----------------------------------------------------- | ------------------------------------------------------------- |
| `models/common_models.py` — `PlatformVersion.v1`      | `"platform.huybrechts.xyz/v1"` → `"strata.huybrechts.xyz/v1"` |
| `controllers/solution_controller.py` (line 173)       | hardcoded string literal                                      |
| `src/strata/data/configuration.yaml`                  | apiVersion field                                              |
| `templates/configuration/*.yaml` (6 files)            | apiVersion field                                              |
| `templates/examples/aks/scaffold/**/*.yaml` (5 files) | apiVersion field                                              |
| `templates/platform.instructions.md`                  | example snippet                                               |
| Generated `.strata/schemas/*.json`                    | `$schema` / example values                                    |

## Backwards compatibility

All existing YAML files (including the entire haven workspace) will fail
schema validation after the rename until they are updated. This is a
**breaking change** — requires a major or at minimum a minor version bump
with a migration note.

**Migration path:**
- Accept both values during a transition period via an alias in `PlatformVersion`
- Ship a `strata migrate apiversion` command (or a sed one-liner in the release notes)

## Proposed issue (raise in strata repo)

**Title:** Rename `apiVersion` from `platform.huybrechts.xyz/v1` to `strata.huybrechts.xyz/v1`

**Labels:** `breaking-change`, `api`, `naming`

**Body:**

> The `apiVersion` field in all strata YAML documents currently reads
> `platform.huybrechts.xyz/v1`. This is inconsistent with the product name
> ("strata"), the package name (`xyz-strata`), and the docs URL
> (`docs.strata.huybrechts.xyz`).
>
> **Proposed change:** rename to `strata.huybrechts.xyz/v1`.
>
> The root cause is `PlatformVersion.v1` in `models/common_models.py` —
> a one-line fix that cascades to all templates and generated schemas.
>
> A transition alias and migration tooling should accompany the release.

## Notes

- Discovered during haven workspace setup (2026-05-21).
- All haven YAML files currently use `platform.huybrechts.xyz/v1` and will
  need a bulk find-and-replace once strata ships the fix.
