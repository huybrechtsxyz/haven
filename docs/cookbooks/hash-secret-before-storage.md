# Cookbook: Storing a Hashed Secret Before Storage

> Works today with existing `strata secret` commands — no strata changes needed.

[← Back to Guide](../index.rst)

## Problem

Some backends expect a **pre-hashed** value rather than plaintext. Vaultwarden's `ADMIN_TOKEN` is the motivating case: Vaultwarden hashes the token itself (Argon2id) and expects the **hash** in its environment, but a human still needs the **raw** plaintext to actually log in to the admin panel.

If you don't want to wait for the `post_generate` hook (see [setup.md → Automated Secrets Generation](../guides/setup.md#automated-secrets-generation)), this two-key workflow works right now with the existing `strata secret` commands.

## Prerequisites

Declare **two** keys in your environment YAML, each with an **integration-backed** `store:` (`bitwarden`, `vault`, `azure-keyvault`, or `infisical` — `put` cannot write to `constant`/`environment`/`github` stores):

```yaml
# deploy.yaml
spec:
  secrets:
    - key: VAULTWARDEN_ADMIN_TOKEN_RAW
      store: infisical
      generate:
        type: urlsafe
        length: 48

    - key: VAULTWARDEN_ADMIN_TOKEN_HASH
      store: infisical
```

## Steps

**Run this interactively, from your own terminal — not from an automated pipeline.** The raw value only ever lives transiently in a shell variable, never in a temp file or CLI argument (other than the caveat noted below).

### PowerShell

```powershell
# 1. Bootstrap the raw secret once (run interactively, not in CI)
strata secret put VAULTWARDEN_ADMIN_TOKEN_RAW --generate -f deploy.yaml

# 2. Read it back
$raw = strata secret get VAULTWARDEN_ADMIN_TOKEN_RAW --unmask -f deploy.yaml

# 3. Transform it
$hash = $raw | docker run --rm -i vaultwarden/server /vaultwarden hash --preset owasp

# 4. Store the transformed value under a second key
strata secret put VAULTWARDEN_ADMIN_TOKEN_HASH --value $hash -f deploy.yaml
```

### Bash equivalent

```bash
# 1. Bootstrap the raw secret once (run interactively, not in CI)
strata secret put VAULTWARDEN_ADMIN_TOKEN_RAW --generate -f deploy.yaml

# 2. Read it back
raw=$(strata secret get VAULTWARDEN_ADMIN_TOKEN_RAW --unmask -f deploy.yaml)

# 3. Transform it
hash=$(echo -n "$raw" | docker run --rm -i vaultwarden/server /vaultwarden hash --preset owasp)

# 4. Store the transformed value under a second key
strata secret put VAULTWARDEN_ADMIN_TOKEN_HASH --value "$hash" -f deploy.yaml
```

## Pre-flight check: verify the hash command's output format

The `vaultwarden hash` command prints extra text around the PHC-formatted hash. Confirm what your image version actually outputs before trusting `$hash` in step 3 — don't assume it's a single clean line:

```powershell
"test-value" | docker run --rm -i vaultwarden/server /vaultwarden hash --preset owasp
```

Expected output contains a line matching `$argon2id$v=...$m=...,t=...,p=...$...`. If the command also prints prompts or extra text, extract just the hash line before storing it, e.g.:

```powershell
$hashLine = ($raw | docker run --rm -i vaultwarden/server /vaultwarden hash --preset owasp) |
    Select-String -Pattern '\$argon2(id|i|d)\$' |
    ForEach-Object { $_.Matches[0].Value }
```

## Known caveat

⚠️ `strata secret put --value` currently logs its full arguments (including the value) to strata's local audit log — so step 4 will write the hash into `.strata/audit.log` for now. This is tracked separately and doesn't block this workflow, but be aware the hash (not the raw token) ends up in the local log.

## When to prefer this over the `post_generate` hook

|                         | This cookbook (2 keys, manual steps)                 | `post_generate` hook (1 key, automatic)                                            |
| ----------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Strata version required | Any current release                                  | Requires the hook feature ([scripts/hash_argon2.py](../../scripts/hash_argon2.py)) |
| Manual steps            | 4 commands, run once                                 | 1 command (`strata secret put --generate`)                                         |
| Raw value handling      | Printed via `--unmask`, lives in a shell variable    | Printed to console once during generation                                          |
| Use case                | Interim workaround, or backends without hook support | Steady-state, once available                                                       |

See [setup.md → Secrets for Vaultwarden](../guides/setup.md#secrets-for-vaultwarden) for the automated flow.
