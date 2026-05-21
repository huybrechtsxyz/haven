# TODO: strata — build step does not copy terraform source (.tf files) to build output

## Summary

`strata build run` generates `*.auto.tfvars.json` into `build/<name>/terraform/`
but does **not** copy the IaC source files (`.tf`) from the provisioner
`source_path` to the build folder.

The deploy step (`TerraformDeployer.validate_workspace`) then fails with:

```
No *.tf files found in: build/.../terraform/haven_iac/
  The build step should have copied Terraform source code here.
```

## Root cause — two separate issues

### 1. No automatic source copy in TerraformBuilder

`terraform_builder.py` only calls:
- `_save_terraform_vars(...)` → writes `*.auto.tfvars.json`
- `_process_includes(...)` → merges files listed in `spec.overrides.includes`

There is no step that automatically copies the provisioner `source_path`
(e.g., `terraform/`) into the build folder.

### 2. Working directory mismatch

`TerraformDeployer._get_working_dir` falls back to:
```
deployment_build_path / f"terraform/{iac_model.name}"
```
= `build/haven_deploy_prd-1.0.0/terraform/haven_iac/`

But `TerraformBuilder._save_terraform_vars` always writes tfvars to:
```
deployment_build_path / "terraform"
```
= `build/haven_deploy_prd-1.0.0/terraform/`

These directories don't match. Terraform needs `.tf` files AND
`*.auto.tfvars.json` in the **same** working directory.

## Workaround (haven)

Two changes are required:

### A. Set `target_path: terraform` on the provisioner source in `ws-platform.yaml`

```yaml
provisioners:
  - name: haven_iac
    provisioner: terraform
    source:
      repository: haven
      source_path: terraform
      target_path: terraform   # ← tells deployer to run from build/terraform/
```

This makes `_get_working_dir` return `build/terraform/` (matching tfvars location).

### B. Add `spec.overrides.includes` in `env-prd.yaml` to copy `.tf` source

```yaml
spec:
  overrides:
    includes:
      - source: terraform/*.tf
        target: main.tf          # or per-file entries
        strategy: copy
      - source: terraform/modules/**/*.tf
        target: modules/...
        strategy: copy
```

This copies the IaC source files into `build/terraform/` during `strata build run`.

## Proposed strata fix

`TerraformBuilder.build()` should automatically copy all files from the
provisioner `source_path` into `deployment_build_path / target` (or a sensible
default) before generating tfvars — so the build output is a fully
self-contained terraform working directory.

The `includes` mechanism can then handle environment-specific overrides/additions
on top of that base copy.

## Affected files

- `src/strata/builders/terraform_builder.py` — add source copy step
- `src/strata/deployers/terraform_deployer.py` — `_get_working_dir` fallback
  **FIXED**: now uses `iac_model.source.source_path` instead of `terraform/{iac_model.name}`
- `src/strata/models/workspace_model.py` — `WorkspaceIacModel.source.target_path`
  should default to `"terraform"` (not None)
