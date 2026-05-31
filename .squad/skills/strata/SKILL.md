# Strata CLI — Team Skill

> **Scope:** Haven project — first production use of strata (xyz-strata v0.0.x)
> **Maintainers:** Kaylee (infra), Zoe (validation) — both append surprises here
> **Confidence:** low (early adopter, actively accumulating)

This file captures what the team has learned about strata's actual behavior — especially where it diverges from expectations. It is the primary feedback channel from the team to the strata developers (Vincent).

---

## Known Facts

- **Binary location:** `C:\Users\VHUYBREC\.local\bin\strata.exe`
- **`strata` is NOT on PATH** — must use full path or set an alias. Run `uv tool update-shell` to fix permanently.
- **Install command:** `uv tool install e:\SourcesXYZ\strata`
- **Supported kinds:** `configuration`, `deployment`, `environment`, `firewall`, `module`, `namespace`, `platform_model`, `provider`, `resource`, `workspace`
- **Templates available for `strata new`:** `configuration`, `firewall`, `module`, `namespace`, `provider`, `resource`, `workspace` (note: `deployment` and `environment` are NOT available as templates)
- **Validate syntax:** `strata validate <file-path>` — one file at a time; no glob support observed
- **Deep validation:** `strata validate --deep <file>` — requires initialized workspace with active profile

---

## Observed Surprises

### 2026-05-29 — apiVersion enum mismatch (Kaylee + Zoe)

**What happened:** `strata validate` on `dc-hetzner-eu-de.yaml` failed with:
```
Field 'apiVersion': must be one of: 'platform.huybrechts.xyz/v1' (type: enum)
```
The file used `strata.huybrechts.xyz/v1` which is the value shown in all existing YAML examples.

**Resolution:** The schema validator expects `platform.huybrechts.xyz/v1` but the canonical value in the codebase is `strata.huybrechts.xyz/v1`. Vincent confirmed `strata.huybrechts.xyz/v1` is correct — the schema is outdated. An `update` command is being built to migrate this in bulk when the schema is updated.

**Status:** Known — schema fix + `strata update` command pending. Keep `strata.huybrechts.xyz/v1` in all files for now.

---

### 2026-05-29 — Integration capability enum is undocumented (Kaylee)

**What happened:** `strata validate` on `config/haven-config.yaml` failed with:
```
spec -> integrations -> 2 -> capabilities: Value error, Invalid capability names: {'configuration'}
spec -> integrations -> 3 -> capabilities: Value error, Invalid capability names: {'deployment'}
```

**Valid capability names (confirmed):** `api`, `container`, `features`, `infrastructure`, `keyvalue`, `repository`, `secrets`, `variables`

**Mappings to use:**
- Ansible → `infrastructure` (not `configuration`)
- Helm → `container` (not `deployment`)
- Terraform/OpenTofu → `infrastructure`
- Git → `repository`
- Infisical/Bitwarden → `secrets`

**Resolution from strata team (2026-05-29):** `infrastructure` and `container` are deliberate umbrella terms — `configuration` and `deployment` will NOT be added to the enum as they would be ambiguous aliases. Fix is documentation only: protocol docstrings, registry examples, field description, and the docs table are being updated to make the umbrella-term design explicit.

**Status:** ✅ Closed — by design. Our mappings above are correct and final.

---

## Patterns That Work

*(Append here when a pattern is confirmed reliable across multiple uses)*

---

## Open Questions

- Does `strata validate --deep` require a `strata profile add` to be run first?
- Does `strata build` / `strata deploy` work standalone or require a full solution setup?
- Are `deployment` and `environment` kinds intentionally excluded from `strata new` templates?
