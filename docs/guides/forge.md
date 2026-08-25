# Haven Forge

> This document describes deploying and configuring the Forge VPS — the workload node.

[← Back to Guide](./index.md)

Forge is the workload VPS. It runs a single-node k3s cluster on a Hetzner CPX41, hosting self-hosted apps — each in its own Kubernetes namespace so they can be added, changed, or removed independently.

**Prerequisites:** `deploy-infra.yml` must have run successfully (VPS + firewall exist, see [infrastructure.md](./infrastructure.md)), DNS A records for each app's hostname must be configured at INWX pointing directly at Forge's public IP (see [Design decision](#design-decision--forge-terminates-its-own-ingress) below), and all Infisical Cloud secrets must already be populated (see [setup.md](./setup.md)).

---

## Design decision — Forge terminates its own ingress

Unlike Hearth's services (fronted by Caddy), Forge apps are reached directly — Forge's firewall (`config/forge/firewall.yaml`) has inbound `80`/`443` open to the whole internet, with **no** `from:` restriction, unlike SSH/k3s-API/Flannel which are scoped to the private network only. k3s runs **Traefik** (its built-in default) for ingress — re-enabled deliberately; it used to be disabled under a stale assumption (carried over from an older archive) that Caddy-on-Hearth would proxy to Forge.

This keeps the two-node split's whole point intact: **Hearth stays stable** (only routine upgrades, never touched when Forge's app set changes) while **Forge can change freely** — adding, removing, or reconfiguring apps never requires touching Hearth's Caddy config. `docs/design.md`'s risk table already anticipated this: *"cert-manager on Forge + Caddy on Hearth provide dual renewal paths"* — two independent TLS points, not one proxying through the other.

TLS is not wired up yet on Forge — no cert-manager/ClusterIssuer exists yet, so every Forge app is currently reachable over plain HTTP through Traefik only. HTTPS is a separate, still-open task.

---

## Design decision — LAN routing between Hearth and Forge

Both VPS's share a private Hetzner network (`deploy/terraform/main.tf`'s `hcloud_network.haven`), with `hearth_private_ip`/`forge_private_ip` exposed as Terraform outputs. Infra-level traffic (SSH, k3s API, Flannel VXLAN) is already scoped to it.

Application-level traffic wasn't — Forge apps authenticating against Hearth's Authentik (OIDC) would resolve `auth.{domain}` via public DNS → Hearth's *public* IP → out over the internet and back, despite both servers sitting on the same private network. `deploy-forge.yml`'s config phase now fixes this: it queries the Hetzner API for Hearth's private IP and passes it to `forge-config.yml`, which adds a static `/etc/hosts` entry mapping `auth.{domain}` → Hearth's private IP. The hostname stays the same, so TLS SNI / certificate validation against Caddy's real cert is unaffected — only DNS resolution changes.

---

## What runs where

| Namespace (k8s) | Guide                                           | Purpose                                                                                                       |
| --------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `immich`        | [services/immich.md](../services/immich.md)     | Photo/video management (Immich + its own Postgres/library modules)                                            |
| `media`         | [services/jellyfin.md](../services/jellyfin.md) | Media streaming (Jellyfin)                                                                                    |
| `system`        | *(this doc, below)*                             | Cross-cutting cluster tooling not tied to one app layer — Portainer's Kubernetes agent, cert-manager (future) |
| *(future)*      | —                                               | Other self-hosted apps get their own namespace each, same pattern                                             |

Each app group gets its own strata namespace file under `config/forge/namespaces/` and its own Kubernetes namespace — deliberately not shared, so apps can't collide or take each other down.

---

## Portainer Kubernetes agent

Hearth's existing Portainer instance can manage Forge's k3s cluster too — Portainer CE natively supports adding both Docker *and* Kubernetes environments from one instance, so no second Portainer deployment is needed on Forge.

**Not yet wired in as a strata module.** The agent needs `cluster-admin` RBAC, and the correct manifest for your exact running Portainer version should come from Portainer's own setup wizard — not a hand-authored or hardcoded one, since versions must match and getting cluster-admin YAML wrong is exactly the kind of thing worth avoiding.

To set it up:

1. In Portainer (on Hearth): **Environments → Add environment → Kubernetes → via agent** — this generates a `kubectl apply -f ...` command specific to your installed Portainer version.
2. Run that command against Forge (over the LAN — see [LAN routing](#design-decision--lan-routing-between-hearth-and-forge) above).
3. Back in Portainer, finish adding the environment using the agent's address on Forge's private IP.
4. Once working, capture the resulting manifest as a local Helm chart under `services/forge/portainer-agent/` + a `config/forge/modules/portainer-agent.yaml` module, referenced from a new `config/forge/namespaces/system.yaml` (strata rejects empty namespaces — this one needs at least this module before it can be created) — same pattern as the other namespaces in this repo.

---

## Forge Init (`deploy-forge-init.yml`)

One-time bootstrap of a fresh server: installs k3s (Traefik enabled), creates the `haven` service user, optionally mounts the Storage Box NFS share, hardens SSH, and generates the BorgBackup SSH key pair. Idempotent — safe to re-run, but normally only needed once per server.

| Input            | Value         | Notes                                                                                                      |
| ---------------- | ------------- | ---------------------------------------------------------------------------------------------------------- |
| `branch`         | *your branch* | Must match the branch the workflow is running on                                                           |
| `dry_run`        | `false`       | `true` skips playbook execution entirely (preview)                                                         |
| `configure_borg` | `false`       | Initialise the BorgBackup repo on Storage Box — only after the SSH key is authorised in Hetzner Robot      |
| `configure_nfs`  | `false`       | Mount the Storage Box NFS share at `/mnt/storagebox` — requires `storagebox_nfs_share` (a GitHub Variable) |

---

## Forge Config + Deploy (`deploy-forge.yml`)

| Input        | Value         | Notes                                                                                                                                   |
| ------------ | ------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `branch`     | *your branch* | Must match the branch the workflow is running on                                                                                        |
| `dry_run`    | `false`       | `true` skips playbook execution entirely (preview)                                                                                      |
| `run_config` | `true`        | Runs `forge-config.yml` — currently: LAN-routes Forge → Hearth's Authentik via the `/etc/hosts` override above                          |
| `run_deploy` | `true`        | **Not yet functional** — `forge-deploy.yml` (the playbook that would run `helm upgrade` for each namespace's modules) doesn't exist yet |

---

## Secrets

| Secret                      | Store     | Used by                                       |
| --------------------------- | --------- | --------------------------------------------- |
| `BORG_PASSPHRASE_FORGE`     | Infisical | `forge-init.yml`'s BorgBackup repo init       |
| `STORAGEBOX_FORGE_PASSWORD` | Infisical | `forge-init.yml`'s Storage Box SSH key upload |

Per-app secrets (e.g. `IMMICH_DB_PASSWORD`, `JELLYFIN_SSO_CLIENT_SECRET`) are documented in each app's own guide under [docs/services/](../services/).

---

## Verification checklist

- [ ] `kubectl get nodes` shows the Forge node `Ready`
- [ ] `kubectl get pods -A` shows Traefik running in `kube-system`
- [ ] Storage Box NFS mounted at `/mnt/storagebox` on the host (`mount | grep storagebox`)
- [ ] BorgBackup repokey saved (from the `deploy-forge-init.yml` run log) to Bitwarden
- [ ] `/etc/hosts` on Forge has an entry for `auth.{domain}` pointing at Hearth's private IP

---

## Still open

- No TLS/cert-manager on Forge yet — every app is HTTP-only for now
- `forge-deploy.yml` doesn't exist yet — namespaces/modules validate and build via strata, but nothing actually runs `helm upgrade` against the live cluster yet
- No `apps` namespace or additional self-hosted apps beyond Immich/Jellyfin yet
