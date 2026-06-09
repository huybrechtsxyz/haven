### 2026-06-07: Production update safety strategy — deferred

**By:** Vincent Huybrechts
**What:** Before Haven Hearth goes live with real family data, we need a safe update/rollback strategy. Current deploy is fire-and-forget — `docker compose pull` + `up -d` with no pre-update backup and no rollback path.
**Why:** Authentik, Infisical, and Vaultwarden all run DB migrations on upgrade. A failed migration on production = data inconsistency, no rollback, and cascade failure (Authentik is SSO trust root for everything).

**Agreed approach (design, not yet implemented):**
- Pin all image tags — no `:latest`, explicit versions, intentional upgrades only
- Pre-update Ansible task: `pg_dump` Authentik + Infisical DBs, copy Vaultwarden SQLite — written to BorgBackup path before any pull
- Post-update health gate: check each service responds after `up -d`; fail playbook if not
- Rollback path: restore DB dump + restart previous image tag
- Stage updates: one service at a time, not whole stack
- Local test path: run Hearth stack in devcontainer first — test the upgrade locally before pushing to production (see devcontainer work item below)

**Deferred until:** Wave 1 services are stable and soak-gated — implement before any production update is attempted.

**Related:** devcontainer local Hearth environment (same inbox item)

---

### 2026-06-07: Devcontainer approach — Docker-in-Docker (DinD)

**By:** Vincent Huybrechts
**What:** Local Hearth environment for upgrade testing will use Docker-in-Docker (DinD), not host socket mount.
**Why:** Devcontainers can only be run on the work laptop (not home machines). DinD keeps the local Hearth stack fully isolated inside the devcontainer — no host Docker pollution, clean teardown. Use `ghcr.io/devcontainers/features/docker-in-docker` feature.
**Constraint:** Work laptop only — devcontainer is not available on home/personal machines.
