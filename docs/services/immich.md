# Immich

> Immich — self-hosted photo and video management, self-hosted on Forge (k3s).

## Overview

Immich runs on **Forge** (Hetzner CPX41, k3s), in its own `immich` Kubernetes namespace — separate from Jellyfin's `media` namespace and any future self-hosted-app namespaces, so apps can be added/changed independently without colliding. See [Forge](../guides/forge.md) for the node-level overview.

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once (k3s + Traefik installed, Storage Box SMB mounted at `/mnt/storagebox`), and a DNS A record for `photos.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

> ✅ Verified end-to-end in production (2026-08-27) — `strata deploy run --scope apps --stage applications_forge` successfully deployed `immich-library`, `immich-postgres`, and `immich` (server, machine-learning, cache) into the live `immich` namespace on Forge.

---

## What gets deployed

Three Helm modules make up the `immich` namespace, in dependency order:

| Module            | Chart / source                                                      | Purpose                                                              |
| ----------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `immich-library`  | Local chart, `services/forge/immich-library/`                       | Static PV/PVC for the photo/video library (Storage Box NFS-backed)   |
| `immich-postgres` | Local chart, `services/forge/immich-postgres/`                      | Single-pod PostgreSQL with the vectorchord extension Immich requires |
| `immich`          | `oci://ghcr.io/immich-app/immich-charts` (chart `immich`, `0.13.1`) | Immich server, machine learning, and cache                           |

`image.tag` for the `immich` module's server/ML containers is pinned to `v3.0.0` — confirmed against chart 0.13.1's own `Chart.yaml` (`appVersion: v3.0.0`) and default `values.yaml`.

> Immich's chart moved to OCI-only distribution (the old HTTP repo is deprecated/frozen) — this required strata 1.8.3+ (OCI `chart_repository` support and the `${KEY}` Helm secret-substitution fix), both confirmed fixed and in use. See the module comments in `config/forge/modules/immich.yaml` for details.

---

## Architecture decisions

| Component       | Choice                                                                                      | Why                                                                                                                                                                                                                                                                                                      |
| --------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Postgres        | Single pod, official `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0` image | Has the vectorchord extension pre-installed; no operator (CNPG) or Bitnami subchart needed for one small family server                                                                                                                                                                                   |
| Redis           | Plain `redis:7-alpine`, swapped into the chart's bundled `valkey:` dependency slot          | Keeps the chart's automatic `REDIS_HOSTNAME` wiring; simplest single-pod cache. **Note:** the chart's default liveness/readiness/startup probes assume `valkey-cli` (not present in plain redis images) — `immich.yaml` overrides these to use `redis-cli` instead, matching the original probe timings. |
| Library storage | Static `hostPath` PV/PVC at `/mnt/storagebox/immich`                                        | Reuses the *same* Storage Box SMB mount `forge-init.yml` already sets up on the host — no in-pod CIFS CSI driver needed for a single-node cluster                                                                                                                                                        |

---

## Secrets

| Secret               | Store     | Used by                                                          |
| -------------------- | --------- | ---------------------------------------------------------------- |
| `IMMICH_DB_PASSWORD` | Infisical | `immich-postgres`'s `POSTGRES_PASSWORD` + Immich's `DB_PASSWORD` |

---

## Verification checklist

- [x] `strata build run`/`strata deploy run --scope apps --stage applications_forge` complete successfully
- [x] `immich-postgres`, `immich-valkey`, `immich-machine-learning`, `immich-server` pods all reach `Ready` on the live cluster
- [ ] `http://photos.{domain}` — Immich loads and is reachable from a browser (plain HTTP until TLS is wired up)
- [ ] Photo/video library reads/writes to `/mnt/storagebox/immich`

---

## Still open

- No TLS/cert-manager on Forge yet — Immich is HTTP-only for now
- No SSO wired up yet for Immich (it has native OIDC support, unlike Jellyfin — not yet configured against Authentik)
