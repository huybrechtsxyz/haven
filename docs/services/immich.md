# Immich

> Immich — self-hosted photo and video management, self-hosted on Forge (k3s).

## Overview

Immich runs on **Forge** (Hetzner CPX41, k3s), in its own `immich` Kubernetes namespace — separate from Jellyfin's `media` namespace and any future self-hosted-app namespaces, so apps can be added/changed independently without colliding. See [Forge](../guides/forge.md) for the node-level overview.

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once (k3s + Traefik installed, Storage Box NFS mounted at `/mnt/storagebox`), and a DNS A record for `photos.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## What gets deployed

Three Helm modules make up the `immich` namespace, in dependency order:

| Module            | Chart / source                                                      | Purpose                                                              |
| ----------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `immich-library`  | Local chart, `services/forge/immich-library/`                       | Static PV/PVC for the photo/video library (Storage Box NFS-backed)   |
| `immich-postgres` | Local chart, `services/forge/immich-postgres/`                      | Single-pod PostgreSQL with the vectorchord extension Immich requires |
| `immich`          | `oci://ghcr.io/immich-app/immich-charts` (chart `immich`, `0.13.1`) | Immich server, machine learning, and cache                           |

`image.tag` for the `immich` module's server/ML containers is pinned to `v3.0.0` — confirmed against chart 0.13.1's own `Chart.yaml` (`appVersion: v3.0.0`) and default `values.yaml`.

> ⚠️ **Blocked on a strata bug**: Immich's chart moved to OCI-only distribution (the old HTTP repo is deprecated/frozen). Strata's current Helm deployer doesn't support `oci://` chart repositories correctly, and its `${KEY}` secret-substitution mechanism for Helm values doesn't actually resolve at deploy time — both were found and written up while building this module, targeted for a future strata release. See the module comments in `config/forge/modules/immich.yaml` for details.

---

## Architecture decisions

| Component       | Choice                                                                                      | Why                                                                                                                                              |
| --------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Postgres        | Single pod, official `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0` image | Has the vectorchord extension pre-installed; no operator (CNPG) or Bitnami subchart needed for one small family server                           |
| Redis           | Plain `redis:7-alpine`, swapped into the chart's bundled `valkey:` dependency slot          | Keeps the chart's automatic `REDIS_HOSTNAME` wiring; simplest single-pod cache                                                                   |
| Library storage | Static `hostPath` PV/PVC at `/mnt/storagebox/immich`                                        | Reuses the *same* Storage Box NFS mount `forge-init.yml` already sets up on the host — no in-pod NFS CSI driver needed for a single-node cluster |

---

## Secrets

| Secret               | Store     | Used by                                                          |
| -------------------- | --------- | ---------------------------------------------------------------- |
| `IMMICH_DB_PASSWORD` | Infisical | `immich-postgres`'s `POSTGRES_PASSWORD` + Immich's `DB_PASSWORD` |

---

## Verification checklist

- [ ] `strata build run` produces `build/<deployment>/immich/{immich,immich-postgres,immich-library}/{values,meta}.yaml` without errors (blocked today by an unrelated, pre-existing strata `variables.tf` validation issue — see repo notes)
- [ ] Both strata Helm bugs above are fixed/worked around before attempting a real deploy
- [ ] `http://photos.{domain}` — Immich loads (plain HTTP until TLS is wired up)
- [ ] Postgres pod healthy, Immich connects successfully
- [ ] Photo/video library reads/writes to `/mnt/storagebox/immich`

---

## Still open

- No TLS/cert-manager on Forge yet — Immich is HTTP-only for now
- `forge-deploy.yml` (the Ansible playbook that would run `helm upgrade`) doesn't exist yet
- `image.tag` needs to be pinned to a real, verified release before deploying
- No SSO wired up yet for Immich (it has native OIDC support, unlike Jellyfin — not yet configured against Authentik)
