# Decision: CI/CD Workflow Architecture — Call Strata or Own It?

**Date:** 2026-05-31
**Author:** Mal
**Status:** Decision — pending implementation by Kaylee

---

## Recommendation

**Own the workflow. Go with Option C.**

The relative-action-path constraint is the deciding factor: calling `huybrechtsxyz/strata/.github/workflows/deploy-workspace.yml@v0.0.5` from haven still requires copying all three composite actions into haven's `.github/actions/` — so Option A provides zero duplication savings and splits logical ownership across two repos with no upside. Haven is also the *first* production consumer of strata, which makes live coupling to `@main` a liability, not a feature; every breaking strata change becomes a silent haven breakage. Since deploy.yml is still a template and hasn't gone live yet, now is exactly the right moment to instantiate it properly as haven's own workflow. Copy the three composite actions as a starting point, adapt as needed, and pull in the v0.0.5 improvements (concurrency control, yq install, `strata tools status` check). After that, haven tracks strata improvements deliberately — when something useful lands in strata, it gets reviewed and ported, not silently inherited.

---

## Options Evaluated

### Option A — Call strata's `deploy-workspace.yml` + copy 3 composite actions to haven

|         |                                                                                                         |
| ------- | ------------------------------------------------------------------------------------------------------- |
| **Pro** | Workflow logic stays in one place (strata repo)                                                         |
| **Pro** | Version-pinnable via `@v0.0.5`                                                                          |
| **Con** | **Relative action paths mean the 3 actions must live in haven anyway** — there is no actual DRY benefit |
| **Con** | Workflow logic split across two repos; debugging requires context-switching                             |
| **Con** | strata's workflow interface (inputs/outputs) can change and silently break haven                        |
| **Con** | Haven has no say in what the workflow does without forking strata                                       |

### Option B — Copy `deploy-workspace.yml` into haven, keep composite actions in haven

|         |                                                                                                               |
| ------- | ------------------------------------------------------------------------------------------------------------- |
| **Pro** | Full ownership; no cross-repo runtime dependency                                                              |
| **Pro** | Can rename, restructure, and adapt freely                                                                     |
| **Con** | Effectively identical to Option C but starts from a strata-shaped file that may not fit haven's template vars |
| **Con** | Still requires manual sync when strata improves the workflow                                                  |

### Option C — Keep haven's inline `deploy.yml`, update it with v0.0.5 improvements ✅ CHOSEN

|         |                                                                                                  |
| ------- | ------------------------------------------------------------------------------------------------ |
| **Pro** | Complete ownership; no cross-repo dependency at runtime                                          |
| **Pro** | Selective adoption — improvements are reviewed before they land in production                    |
| **Pro** | haven's template vars (`${name}`, `${file}`, `${environment}`) are instantiated on haven's terms |
| **Pro** | Single source of truth for haven's deployment logic                                              |
| **Con** | Manual effort to track strata improvements going forward                                         |
| **Con** | Three composite actions need to be written/copied once                                           |

---

## Implementation Instructions (for Kaylee)

1. Instantiate `deploy.yml` — replace template vars `${name}`, `${file}`, `${environment}` with haven's actual values.
2. Copy strata's three composite actions into haven:
   - `.github/actions/setup-strata/action.yml`
   - `.github/actions/setup-yq/action.yml`
   - `.github/actions/verify-integrations/action.yml`
3. Update `deploy.yml` to:
   - Use the copied composite actions instead of inline `pip install xyz-strata`
   - Add concurrency control (cancel in-progress runs on same branch)
   - Add the `verify-integrations` step after tool setup, before validate
4. Uncomment and configure the Bitwarden secrets block (that's the chosen secret manager for haven-prd).
5. Do **not** call `huybrechtsxyz/strata/.github/workflows/deploy-workspace.yml` — the actions resolve to the caller repo anyway and the coupling is not worth it.

---

## Version Pinning Policy

- Composite actions reference strata's patterns but live in haven — no version pinning needed for those.
- `actions/checkout`, `actions/setup-python`, `hashicorp/setup-terraform` stay pinned at their current major versions.
- strata CLI pinned to `xyz-strata==0.0.5` in the setup action until explicitly bumped and tested.

---

## Review Gate

This decision does not require a second approval (architectural scope, no infra changes). Kaylee may proceed to implementation.
