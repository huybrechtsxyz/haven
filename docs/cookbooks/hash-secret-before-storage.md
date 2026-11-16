# Cookbook: Storing a Hashed Secret Before Storage

[← Back to Guide](../index.rst)

## Problem

Some backends expect a **pre-hashed** value rather than plaintext. Vaultwarden's `ADMIN_TOKEN` is the motivating case: Vaultwarden expects the **Argon2id hash** of the admin token in its environment, but a human still needs the **raw** plaintext to log in to the admin panel.

strata v2 has no post-generate hook, so this is a two-key workflow with one manual step, run whenever the raw token is generated or rotated.

## The two keys

Both are declared in [`config/environments/prd.yaml`](../../config/environments/prd.yaml) with an **integration-backed** `store:` (`infisical` here — `strata values set` cannot write to `constant`/`environment`/`github` stores):

```yaml
spec:
  secrets:
    - key: VAULTWARDEN_ADMIN_TOKEN      # raw token — what you type at /admin
      store: infisical
      value: VAULTWARDEN_ADMIN_TOKEN
      generate:
        type: urlsafe
        length: 48
    - key: VAULTWARDEN_ADMIN_ARGON      # its Argon2 hash — what Vaultwarden gets
      store: infisical
      value: VAULTWARDEN_ADMIN_ARGON
```

The Hearth module ([`config/hearth/modules/vaultwarden.yaml`](../../config/hearth/modules/vaultwarden.yaml)) sets `ADMIN_TOKEN: "${secret:VAULTWARDEN_ADMIN_ARGON}"`.

## Steps

**Run this interactively, from your own terminal — not from an automated pipeline.** It needs Docker and the Infisical credentials (`INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET`, `INFISICAL_PROJECT_ID`) in the environment.

### Recommended: one pipe

```bash
# 1. Generate the raw token (skip if it already exists — strata also creates it
#    on first use because of its generate: spec)
strata values set haven_deploy_prd --key VAULTWARDEN_ADMIN_TOKEN --generate

# 2. Hash it and store the hash — neither value lands in a shell variable,
#    a temp file or a command-line argument
strata values get haven_deploy_prd VAULTWARDEN_ADMIN_TOKEN --format raw \
  | python scripts/hash_argon2.py \
  | strata values set haven_deploy_prd --key VAULTWARDEN_ADMIN_ARGON --stdin
```

[`scripts/hash_argon2.py`](../../scripts/hash_argon2.py) runs `vaultwarden hash --preset owasp` in the official image and prints only the hash line.

### Manual equivalent (PowerShell)

```powershell
strata values set haven_deploy_prd --key VAULTWARDEN_ADMIN_TOKEN --generate
$raw = strata values get haven_deploy_prd VAULTWARDEN_ADMIN_TOKEN --format raw
$hash = ("$raw`n$raw`n" | docker run --rm -i vaultwarden/server /vaultwarden hash --preset owasp) |
    Select-String -Pattern '\$argon2(id|i|d)\$\S+' | ForEach-Object { $_.Matches[0].Value }
$hash | strata values set haven_deploy_prd --key VAULTWARDEN_ADMIN_ARGON --stdin
```

`vaultwarden hash` prompts for the password twice, hence `"$raw`n$raw`n"`, and prints extra text around the hash, hence the `Select-String`.

## Pre-flight check: verify the hash command's output format

Confirm what your image version actually outputs before trusting the extracted hash:

```powershell
"test-value`ntest-value`n" | docker run --rm -i vaultwarden/server /vaultwarden hash --preset owasp
```

Expected output contains a line matching `$argon2id$v=...$m=...,t=...,p=...$...`.

## Afterwards

- Copy the raw `VAULTWARDEN_ADMIN_TOKEN` into Bitwarden once — you need it to log in, and it cannot be recovered from the hash.
- Redeploy Hearth (`23 - Hearth - Deploy`) so the new hash reaches the container.

See [setup.md → Secrets for Vaultwarden](../guides/setup.md#secrets-for-vaultwarden) for where this fits in the setup.
