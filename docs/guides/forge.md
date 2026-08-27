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

Application-level traffic wasn't — Forge apps authenticating against Hearth's Authentik (OIDC) would resolve `auth.{domain}` via public DNS → Hearth's *public* IP → out over the internet and back, despite both servers sitting on the same private network. `deploy-forge-config.yml` now fixes this: it queries the Hetzner API for Hearth's private IP and passes it to `forge-config.yml`, which adds a static `/etc/hosts` entry mapping `auth.{domain}` → Hearth's private IP. The hostname stays the same, so TLS SNI / certificate validation against Caddy's real cert is unaffected — only DNS resolution changes.

---

## What runs where

| Namespace (k8s) | Guide                                                                                          | Purpose                                                                                                                                                                                                          |
| --------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `immich`        | [services/immich.md](../services/immich.md)                                                    | Photo/video management (Immich + its own Postgres/library modules)                                                                                                                                               |
| `media`         | [services/jellyfin.md](../services/jellyfin.md)                                                | Media streaming (Jellyfin)                                                                                                                                                                                       |
| `documents`     | [services/nextcloud.md](../services/nextcloud.md), [services/kavita.md](../services/kavita.md) | Family documents — Nextcloud (Drive replacement) + Kavita (PDF/TTRPG library), sharing the same `haven-docs` S3 bucket via the `rclone-mount` module below                                                       |
| `system`        | *(this doc, below)*                                                                            | Cross-cutting cluster tooling not tied to one app layer — `rclone-mount` (bridges `haven-docs` to a real filesystem path for `documents` apps to share); Portainer's Kubernetes agent and cert-manager to follow |
| *(future)*      | —                                                                                              | Other self-hosted apps get their own namespace each, same pattern                                                                                                                                                |

Each app group gets its own strata namespace file under `config/forge/namespaces/` and its own Kubernetes namespace — deliberately not shared, so apps can't collide or take each other down.

---

## Portainer Kubernetes agent

Hearth's existing Portainer instance can manage Forge's k3s cluster too — Portainer CE natively supports adding both Docker *and* Kubernetes environments from one instance, so no second Portainer deployment is needed on Forge.

**Not yet wired in as a strata module.** The agent needs `cluster-admin` RBAC, and the correct manifest for your exact running Portainer version should come from Portainer's own setup wizard — not a hand-authored or hardcoded one, since versions must match and getting cluster-admin YAML wrong is exactly the kind of thing worth avoiding.

To set it up:

1. In Portainer (on Hearth): **Environments → Add environment → Kubernetes → via agent** — this generates a `kubectl apply -f ...` command specific to your installed Portainer version.
2. Run that command against Forge (over the LAN — see [LAN routing](#design-decision--lan-routing-between-hearth-and-forge) above).
3. Back in Portainer, finish adding the environment using the agent's address on Forge's private IP.
4. Once working, capture the resulting manifest as a local Helm chart under `services/forge/portainer-agent/` + a `config/forge/modules/portainer-agent.yaml` module, added to the existing `config/forge/namespaces/system.yaml` (which already exists, holding `rclone-mount`) — same pattern as every other module in this repo.

---

## rclone-mount — shared filesystem bridge for `haven-docs`

Neither Kavita nor most self-hosted document apps have a native S3 backend — they expect a plain POSIX folder. Nextcloud's External Storage *can* talk to S3 directly, but if Nextcloud used its own S3 connection while Kavita read a separately-mounted copy of the same bucket, the two would be independent S3 clients potentially disagreeing about directory state at any moment.

Instead, `rclone-mount` (`config/forge/modules/rclone-mount.yaml`, `system` namespace) is the single canonical bridge: a privileged pod runs `rclone mount` (FUSE) against the `haven-docs` bucket, publishing it as a real directory tree at `/mnt/haven-docs` on the Forge **host** (not just inside its own pod — `mountPropagation: Bidirectional` makes it visible node-wide). Every consuming app then hostPath-mounts a subpath of that same tree:

- **Nextcloud** → `/mnt/haven-docs` (its External Storage root, once configured — see [services/nextcloud.md](../services/nextcloud.md))
- **Kavita** → `/mnt/haven-docs/games` (read-only)

**Caching trade-off (accepted by design):** `rclone mount` uses `--vfs-cache-mode=writes`, so there's a tunable window where one app's write might not be instantly visible to another. Not real-time shared state, but far tighter than two independent S3 clients — and simple enough for a family server.

---

## Forge Init (`deploy-forge-init.yml`)

One-time bootstrap of a fresh server: installs k3s (Traefik enabled), creates the `haven` service user, optionally mounts the Storage Box SMB share, hardens SSH, and generates the BorgBackup SSH key pair. Idempotent — safe to re-run, but normally only needed once per server.

> ✅ Verified end-to-end in production (2026-08-27) — full run completes with zero failures: k3s install, SMB media mount, SSH hardening, and BorgBackup repo init/repokey export all succeed.

| Input            | Value         | Notes                                                                                                            |
| ---------------- | ------------- | ---------------------------------------------------------------------------------------------------------------- |
| `branch`         | *your branch* | Must match the branch the workflow is running on                                                                 |
| `dry_run`        | `false`       | `true` skips playbook execution entirely (preview)                                                               |
| `configure_borg` | `false`       | Initialise the BorgBackup repo on Storage Box — only after the SSH key is authorised in Hetzner Robot            |
| `configure_smb`  | `false`       | Mount the Storage Box SMB share at `/mnt/storagebox` (media library) — Storage Box subaccounts don't support NFS |

---

## Forge Config (`deploy-forge-config.yml`)

| Input     | Value         | Notes                                              |
| --------- | ------------- | -------------------------------------------------- |
| `branch`  | *your branch* | Must match the branch the workflow is running on   |
| `dry_run` | `false`       | `true` skips playbook execution entirely (preview) |

Runs `forge-config.yml` — currently: LAN-routes Forge → Hearth's Authentik via the `/etc/hosts` override above.

## Forge Deploy (`deploy-forge-deploy.yml`)

| Input     | Value         | Notes                                                                     |
| --------- | ------------- | ------------------------------------------------------------------------- |
| `branch`  | *your branch* | Must match the branch the workflow is running on                          |
| `dry_run` | `false`       | `true` runs validate + build only, skips the actual Helm deploy (preview) |

Runs `strata deploy run --scope apps --stage applications_forge` — tunnels to the k3s API over SSH (fetches the node's own kubeconfig, no public LB needed) and deploys whichever namespaces are currently active in `config/stack/workspace.yaml`.

> ✅ Verified end-to-end in production (2026-08-27) — first real Helm deployment succeeded, deploying `rclone-mount` into the `system` namespace on the live cluster. Note: `deploy-forge-config.yml` is not a hard prerequisite for namespaces with no Authentik/SSO dependency (like `system`) — it only matters once SSO-enabled apps (Immich, Nextcloud) are activated.

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
- [ ] Storage Box SMB share mounted at `/mnt/storagebox` on the host (`mount | grep storagebox`)
- [ ] BorgBackup repokey saved (from the `deploy-forge-init.yml` run log) to Bitwarden
- [ ] `/etc/hosts` on Forge has an entry for `auth.{domain}` pointing at Hearth's private IP

---

## Still open

- No TLS/cert-manager on Forge yet — every app is HTTP-only for now
- Only the `system` namespace (`rclone-mount`) is currently active in `config/stack/workspace.yaml` — `immich`, `media`, and `documents` are pruned out pending their Infisical secrets, to be activated one at a time in that order
- Portainer's Kubernetes agent not yet wired in as a strata module (see [above](#portainer-kubernetes-agent))
