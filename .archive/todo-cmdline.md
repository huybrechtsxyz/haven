# TODO: CLI — inconsistent file argument across commands

## Summary

`strata validate` accepts the deployment file as a **positional argument**
(`FILE_PATH`), while every other file-accepting command uses the `--file` / `-f`
**option**. This breaks muscle memory and contradicts the documented "Next steps"
message printed by `strata sln init`.

The same inconsistency runs deeper: some commands use **positional arguments**
for their primary inputs while others use **named `--options`**, with no clear
rule about which pattern to follow.

## Positional argument vs --option split

| Command                               | Pattern       | Notes                                 |
| ------------------------------------- | ------------- | ------------------------------------- |
| `strata validate <path>`              | positional    | should match `--file` like all others |
| `strata ref config add <name> <path>` | 2 positionals | `--name` / `--path` would be clearer  |
| `strata ref env add <name> <path>`    | 2 positionals | same                                  |
| `strata repo add <name> <url>`        | 2 positionals | `--name` / `--url`                    |
| `strata profile add <name>`           | positional    | `--name`                              |
| `strata profile activate <name>`      | positional    | `--name`                              |
| `strata config set <key> <value>`     | 2 positionals | `--key` / `--value`                   |
| `strata schema <kind>`                | positional    | `--kind`                              |
| `strata tools check <name>`           | positional    | `--name`                              |
| `strata sln export --name <name>`     | `--option` ✅  | inconsistent with the above           |
| `strata new --path <path>`            | `--option` ✅  | inconsistent with the above           |
| `strata deploy run --file <path>`     | `--option` ✅  | —                                     |
| `strata build run --file <path>`      | `--option` ✅  | —                                     |

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

## Error messages reference wrong subcommand name

`--deep` validation (and equivalent build/deploy checks) emit:

```
--deep requires at least one configfile path on the active profile.
Add one with `strata ref configfile add` or remove --deep.
```

The correct command is `strata ref config add` — there is no `configfile` subcommand.
This appears in three places:

| File                                        | Line |
| ------------------------------------------- | ---- |
| `commands/validate/run_validate_command.py` | 228  |
| `commands/builders/base_build_command.py`   | 145  |
| `commands/deploy/base_deploy_command.py`    | 142  |

**Also:** the help docs under `src/strata/data/help/` use `xyz ref configfile add`
(wrong binary name `xyz` instead of `strata`, and wrong subcommand `configfile`).
Affected files: `refs.md`, `quickstart.md`, `profiles.md`, `environments.md`,
`cross-repo.md`.

## Notes

- Discovered during haven workspace setup (2026-05-21).
- `cli_common.py` already has a `click_file` decorator / `--file` option wiring
  that can be reused directly.
