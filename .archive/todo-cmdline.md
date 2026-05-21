# TODO: CLI — inconsistent file argument across commands

## Summary

`strata validate` accepts the deployment file as a **positional argument**
(`FILE_PATH`), while every other file-accepting command uses the `--file` / `-f`
**option**. This breaks muscle memory and contradicts the documented "Next steps"
message printed by `strata sln init`.

## Affected commands

| Command              | Current interface        | Expected        |
| -------------------- | ------------------------ | --------------- |
| `strata validate`    | `strata validate <path>` | `--file` / `-f` |
| `strata deploy run`  | `--file` / `-f` ✅        | —               |
| `strata build run`   | `--file` / `-f` ✅        | —               |
| `strata diff`        | `--file` / `-f` ✅        | —               |
| `strata values list` | `--file` / `-f` ✅        | —               |
| `strata values get`  | `--file` / `-f` ✅        | —               |

## Secondary bug

`init_solution_command.py` (line 223) prints this in the "Next steps" block after
`strata sln init`:

```
3. Validate:  strata validate --file deploy/deploy-prd.yaml
```

That command currently **fails** because `validate` takes a positional argument,
not `--file`. This will confuse new users on first run.

## Proposed issue (raise in strata repo)

**Title:** `strata validate` should use `--file` / `-f` for consistency

**Labels:** `bug`, `cli`, `dx`

**Body:**

> `strata validate` is the only file-accepting command that uses a positional
> argument instead of `--file` / `-f`. All other commands (`deploy run`,
> `build run`, `diff`, `values list/get`) use the shared `@click_file` decorator
> from `cli_common.py`.
>
> **Fix:**
> Replace `@click.argument("file_path")` in `cli_validate.py` with the shared
> `@click_file` decorator (or inline `--file` / `-f` option) so that:
>
> ```bash
> # becomes valid
> strata validate --file config/config.yaml
> strata validate -f config/config.yaml
> ```
>
> **Also fix:** Update the hardcoded "Next steps" message in
> `commands/init/init_solution_command.py` (line 223) which already assumes
> `--file` but the current code rejects it.
>
> Backwards-incompatible change — bump minor version.

## Notes

- Discovered during haven workspace setup (2026-05-21).
- `cli_common.py` already has a `click_file` decorator / `--file` option wiring
  that can be reused directly.
