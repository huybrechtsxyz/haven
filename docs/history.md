# History

> A log of decisions and course-corrections on the haven family platform — things that were tried,
> didn't work out, and were reverted or replaced. For active planning ideas, see
> [future.md](future.md); for the current state of what's deployed, see
> [architecture.md](architecture.md) / [design.md](design.md) and the `docs/services/` folder.

Newest entries first.

---

## 2026-09-27 — RPGKeeper decommissioned

**What**: RPGKeeper (self-hosted TTRPG campaign manager) was deployed to Forge's `gaming` namespace
on 2026-09-25, alongside FoundryVTT.

**Why removed**: after trying it, RPGKeeper didn't cover the intended D&D 5e use case it was added
for — decommissioned two days after deployment.

**What was reverted**: the Helm chart, strata module, Gatus monitor entry, and Authentik
OAuth2Provider/Application/PolicyBinding were all removed. The Authentik objects were deleted via
`state: absent` tombstone blocks in the blueprint (applied through `22 - Hearth - Config`, confirmed
gone in Authentik), then the tombstone blocks themselves were deleted from
[authentik-blueprint.yaml.j2](../deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2) once
confirmed. FoundryVTT, added to the same namespace the same day, was unaffected and remains live.

**Outcome**: the `gaming` namespace now hosts FoundryVTT only — see
[foundryvtt.md](services/foundryvtt.md).
