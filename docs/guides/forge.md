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
| `system`        | *(this doc, below)*                                                                            | Cross-cutting cluster tooling not tied to one app layer — `rclone-mount` (bridges `haven-docs` to a real filesystem path for `documents` apps to share), cert-manager + its ClusterIssuers, and the Portainer Kubernetes Edge Agent |
| *(future)*      | —                                                                                              | Other self-hosted apps get their own namespace each, same pattern                                                                                                                                                |

Each app group gets its own strata namespace file under `config/forge/namespaces/` and its own Kubernetes namespace — deliberately not shared, so apps can't collide or take each other down.

---

## Portainer Kubernetes Edge Agent

Hearth's existing Portainer instance manages Forge's k3s cluster too — Portainer CE natively supports adding both Docker *and* Kubernetes environments from one instance, so no second Portainer deployment is needed on Forge.

**Edge Agent mode**, not the standard agent — Forge's k3s API/firewall has no inbound exposure at all (see [config/forge/firewall.yaml](../../config/forge/firewall.yaml)), so the agent must poll *out* to Portainer over HTTPS rather than Portainer reaching *in* to a NodePort. This needs zero new firewall rules.

**Wired into `forge-init.yml`** (bootstrap step, not a strata Helm module — it's a one-time cluster registration via Portainer's own official install script, not something with a stable chart/manifest to template):

1. In Portainer (on Hearth): **Environments → Add environment → Kubernetes → Edge Agent**. Give it a name (e.g. `forge`).
2. When prompted for a command that generates the Edge ID, use `cat /proc/sys/kernel/random/uuid` (works in any container image, no `uuidgen` dependency). Leave the "URL or IP where exposed containers are reachable" field blank — cosmetic only, doesn't affect the tunnel.
3. Portainer shows a `curl https://downloads.portainer.io/.../portainer-edge-agent-setup.sh | bash -s -- "<EDGE_ID>" "<EDGE_KEY>" ...` command. Store the two values as Infisical secrets `PORTAINER_EDGE_ID`/`PORTAINER_EDGE_KEY` (see [Secrets](#secrets) below) — do **not** commit them anywhere.
4. Run **`31 - Forge - Init`** with `configure_portainer_agent: true`. The playbook runs the official setup script on the node (kubectl is already configured there from the k3s install step) and skips re-running it if the agent deployment already exists.
5. The environment goes from pending to connected in Portainer's Environments list once the agent's first poll succeeds (usually under a minute).

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
| `configure_portainer_agent` | `false` | Install the Portainer Kubernetes Edge Agent — requires the "forge" environment to already exist in Portainer's Environments UI first (see [Portainer Kubernetes Edge Agent](#portainer-kubernetes-edge-agent) above) |

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
>
> ✅ `immich` namespace also verified end-to-end in production (2026-08-27) — Immich server, machine learning, Postgres (vectorchord), and cache all deployed successfully via `strata deploy run --scope apps --stage applications_forge`.

---

## Secrets

| Secret                      | Store     | Used by                                       |
| --------------------------- | --------- | --------------------------------------------- |
| `BORG_PASSPHRASE_FORGE`     | Infisical | `forge-init.yml`'s BorgBackup repo init       |
| `STORAGEBOX_FORGE_PASSWORD` | Infisical | `forge-init.yml`'s Storage Box SSH key upload |
| `PORTAINER_EDGE_ID`         | Infisical | `forge-init.yml`'s Portainer Edge Agent bootstrap — a literal value from Portainer's environment-creation wizard, not generated |
| `PORTAINER_EDGE_KEY`        | Infisical | `forge-init.yml`'s Portainer Edge Agent bootstrap — same wizard, paired with the ID above |

Per-app secrets (e.g. `IMMICH_DB_PASSWORD`, `JELLYFIN_SSO_CLIENT_SECRET`) are documented in each app's own guide under [docs/services/](../services/).

---

## Verification checklist

- [ ] `kubectl get nodes` shows the Forge node `Ready`
- [ ] `kubectl get pods -A` shows Traefik running in `kube-system`
- [ ] Storage Box SMB share mounted at `/mnt/storagebox` on the host (`mount | grep storagebox`)
- [ ] BorgBackup repokey saved (from the `deploy-forge-init.yml` run log) to Bitwarden
- [ ] `/etc/hosts` on Forge has an entry for `auth.{domain}` pointing at Hearth's private IP
- [ ] Forge's environment shows as connected (not pending) in Portainer's Environments list

---

## Still open

- No TLS/cert-manager on Forge yet — every app is HTTP-only for now
- `system` (`rclone-mount`) and `immich` namespaces are active and verified in production; `media` and `documents` are still pruned out in `config/stack/workspace.yaml`, to be activated one at a time in that order
- Portainer's Kubernetes agent not yet wired in as a strata module (see [above](#portainer-kubernetes-agent))
