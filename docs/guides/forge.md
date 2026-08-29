# Haven Forge

> Deploying and operating the Forge VPS — the Haven workload node.

[← Back to Guide](./index.md)

Forge is the workload VPS: a single-node k3s cluster on a Hetzner CPX41 that hosts all self-hosted apps. Each app runs in its own Kubernetes namespace so they can be added, changed, or removed independently without touching anything else.

**Before you start:**

- `deploy-infra.yml` has run successfully, the Forge VPS and its firewall exist (see [infrastructure.md](./infrastructure.md))
- DNS A records for every app hostname point at Forge's public IP at INWX (see [domains.md](./domains.md))
- All Infisical secrets are populated (see [setup.md](./setup.md))

---

## Deployment sequence

### Step 1 — Bootstrap the server

Run **`31 - Forge - Init`** (`deploy-forge-init.yml`) with the flags below. This is idempotent — safe to re-run.

**First run** (installs k3s, creates the `haven` user, hardens SSH — leave optional flags off):

| Input                       | Value         |
| --------------------------- | ------------- |
| `branch`                    | *your branch* |
| `dry_run`                   | `false`       |
| `configure_borg`            | `false`       |
| `configure_smb`             | `false`       |
| `configure_portainer_agent` | `false`       |

After this run completes, the BorgBackup SSH public key is printed in the workflow log. Copy it and **authorise it in Hetzner Robot** (Storage Box → SSH Keys) before continuing.

**Second run** (after SSH key is authorised — enables Borg, SMB mounts, and optionally the Portainer agent):

| Input                       | Value         | Notes                                                                                    |
| --------------------------- | ------------- | ---------------------------------------------------------------------------------------- |
| `branch`                    | *your branch* |                                                                                          |
| `dry_run`                   | `false`       |                                                                                          |
| `configure_borg`            | `true`        | Initialises the BorgBackup repo on the `haven-backup` Storage Box                        |
| `configure_smb`             | `true`        | Mounts the `haven-data` SMB shares at `/mnt/haven-data-media` and `/mnt/haven-data-docs` |
| `configure_portainer_agent` | `true`        | Only if you have completed Step 2 below first                                            |

---

### Step 2 — Connect Portainer

Forge's k3s API has no public exposure — the Portainer Kubernetes Edge Agent polls *out* to Portainer over HTTPS, so no new firewall rules are needed.

1. In Portainer (on Hearth): **Environments → Add environment → Kubernetes → Edge Agent**. Name it `forge`.
2. When asked for a command to generate the Edge ID, use `cat /proc/sys/kernel/random/uuid`.
   Leave the "URL where containers are reachable" field blank — cosmetic only.
3. Portainer shows an install command with `<EDGE_ID>` and `<EDGE_KEY>`. Save both to Infisical as `PORTAINER_EDGE_ID` and `PORTAINER_EDGE_KEY` — do **not** commit them.
4. Re-run **`31 - Forge - Init`** with `configure_portainer_agent: true` (all other flags can stay `false` — the playbook skips already-completed steps).
5. The environment changes from pending to connected in Portainer's Environments list within a minute.

---

### Step 3 — Configure LAN routing

Run **`32 - Forge - Config`** (`deploy-forge-config.yml`):

| Input     | Value         |
| --------- | ------------- |
| `branch`  | *your branch* |
| `dry_run` | `false`       |

This adds a static `/etc/hosts` entry on the Forge VM routing `auth.{domain}` to Hearth's private IP, keeping Authentik traffic on the internal network. This is an optimisation — app SSO works over public DNS too (see [Architecture notes](#architecture-notes) below).

---

### Step 4 — Deploy app namespaces

Run **`33 - Forge - Deploy`** (`deploy-forge-deploy.yml`):

| Input     | Value         | Notes                                                                     |
| --------- | ------------- | ------------------------------------------------------------------------- |
| `branch`  | *your branch* |                                                                           |
| `dry_run` | `false`       | `true` runs validate + build only, skips the actual Helm deploy (preview) |

This runs `strata deploy run --scope apps --stage applications_forge` — tunnels to the k3s API over SSH and deploys all active namespaces in `config/stack/workspace.yaml`.

---

## What runs on Forge

| Namespace   | Guide                                                                                          | Purpose                                                                                        |
| ----------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `system`    | *(this doc)*                                                                                   | cert-manager + ClusterIssuers (TLS for all apps), Portainer Kubernetes Edge Agent              |
| `immich`    | [services/immich.md](../services/immich.md)                                                    | Photo/video management                                                                         |
| `media`     | [services/jellyfin.md](../services/jellyfin.md)                                                | Media streaming (Jellyfin), library on `haven-data` `media` sub-account                        |
| `documents` | [services/nextcloud.md](../services/nextcloud.md), [services/kavita.md](../services/kavita.md) | Nextcloud (file archive) + Kavita (PDF/TTRPG library), both on `haven-data` `docs` sub-account |
| *(future)*  | —                                                                                              | New apps each get their own namespace                                                          |

Storage Box SMB mounts used by app namespaces:

| Mount path              | Storage Box  | Sub-account | Used by           |
| ----------------------- | ------------ | ----------- | ----------------- |
| `/mnt/haven-data-media` | `haven-data` | `media`     | Immich, Jellyfin  |
| `/mnt/haven-data-docs`  | `haven-data` | `docs`      | Nextcloud, Kavita |

---

## Service Configurations

### Immich Setup

See [Immich](../services/immich.md##initial-setup) for detailed setup instructions.

### Jellyfin Setup

See [Jellyfin](../services/jellyfin.md##initial-setup) for detailed setup instructions.

### NextCloud Setup

See [NextCloud](../services/nextcloud.md##initial-setup) for detailed setup instructions.

### Kavita Setup

See [Kavita](../services/kavita.md##initial-setup) for detailed setup instructions.

---

## Secrets

| Secret                             | Store     | Used by                                                                            |
| ---------------------------------- | --------- | ---------------------------------------------------------------------------------- |
| `BORG_PASSPHRASE_FORGE`            | Infisical | BorgBackup repo init (`configure_borg: true`)                                      |
| `STORAGEBOX_BACKUP_FORGE_PASSWORD` | Infisical | Storage Box SSH key upload for BorgBackup                                          |
| `STORAGEBOX_DATA_MEDIA_PASSWORD`   | Infisical | SMB mount credentials for `haven-data` `media` sub-account                         |
| `STORAGEBOX_DATA_DOCS_PASSWORD`    | Infisical | SMB mount credentials for `haven-data` `docs` sub-account                          |
| `PORTAINER_EDGE_ID`                | Infisical | Portainer Edge Agent bootstrap (literal value from Portainer's environment wizard) |
| `PORTAINER_EDGE_KEY`               | Infisical | Portainer Edge Agent bootstrap (paired with the ID above)                          |

Per-app secrets (e.g. `IMMICH_DB_PASSWORD`, `JELLYFIN_SSO_CLIENT_SECRET`) are in each service's own doc under [docs/services/](../services/).

---

## Verification checklist

- [ ] `kubectl get nodes` shows the Forge node `Ready`
- [ ] `kubectl get pods -A` shows Traefik and cert-manager running in `kube-system`
- [ ] `haven-data` Storage Box SMB shares mounted on the host (`mount | grep haven-data`)
- [ ] BorgBackup repokey saved to Bitwarden (from the Forge Init workflow log)
- [ ] `/etc/hosts` on Forge maps `auth.{domain}` to Hearth's private IP
- [ ] Forge environment shows as connected (not pending) in Portainer's Environments list

---

## Architecture notes

### Forge terminates its own ingress

Forge apps are reached directly — Forge's firewall has inbound `80`/`443` open to the internet and k3s runs **Traefik** (its built-in default) as the ingress controller. TLS is issued by cert-manager + Let's Encrypt ClusterIssuers (`letsencrypt-staging`/`letsencrypt-prod`) in the `system` namespace.

This keeps the two-node split's purpose intact: **Hearth stays stable** (never touched when Forge's app set changes) while **Forge changes freely** — adding or removing apps never requires touching Hearth's Caddy config. Caddy on Hearth and cert-manager on Forge are independent TLS renewal paths.

### LAN routing between Hearth and Forge

Both VPSes share a private Hetzner network. Without intervention, Forge pods authenticating against Hearth's Authentik resolve `auth.{domain}` via public DNS — traffic leaves the server and comes back, despite both sitting on the same private network.

`deploy-forge-config.yml` fixes this for VM-level processes: it adds a static `/etc/hosts` entry mapping `auth.{domain}` to Hearth's private LAN IP. TLS still validates correctly because the hostname is unchanged.

**Important:** this `/etc/hosts` override only affects processes running directly on the Forge VM. Kubernetes pods manage their own `/etc/hosts` independently — pod-level OIDC calls (Immich, Jellyfin) resolve via public DNS regardless. Running Forge Config is a networking optimisation, not a prerequisite for SSO. The Portainer Edge Agent pod is an exception — it needed an explicit `hostAliases` patch, now automated in `forge-config.yml`.

### Documents storage

Nextcloud and Kavita both need a plain filesystem path — neither has a native object-storage backend. The `haven-data` Storage Box `docs` sub-account is SMB-mounted on the Forge host at `/mnt/haven-data-docs`, visible node-wide. Apps hostPath-mount into it:

- **Nextcloud** → `/mnt/haven-data-docs` (External Storage root)
- **Kavita** → `/mnt/haven-data-docs/books` (read-only)

SMB is a proper shared filesystem — both apps see the same state at all times with no caching concerns.

---

## Development notes

- `system`/`immich`/`media` namespaces are deployed and running in production (Immich + Jellyfin healthy, HTTPS working, SSO confirmed working for both). `documents` is not yet deployed — pending the SMB storage migration: removing the old `rclone-mount` module, re-pointing Nextcloud/Kavita hostPaths to `/mnt/haven-data-docs`, and wiring `STORAGEBOX_DATA_DOCS_PASSWORD`. The `haven-docs` S3 bucket is being decommissioned; `haven-data` `docs` sub-account is the replacement. No data in `haven-docs` so no content migration needed.

- **Traefik gotcha (2026-08-27, fixed):** An earlier `--disable traefik` flag in the k3s install task was removed at some point but never took effect on the already-provisioned server (the install task is gated on the binary not existing). `forge-init.yml` now has a catch-up task that detects a missing Traefik deployment and re-runs the k3s installer — confirmed fixed.

- **Portainer Edge Agent + `/etc/hosts` (2026-08-27, fixed):** The VM-level `/etc/hosts` LAN-routing trick does not propagate into pods. The Portainer Edge Agent needed a `kubectl patch ... hostAliases` to resolve Hearth over the private network — now automated in `forge-config.yml`. The same pattern applies to any future pod that needs LAN routing to Hearth.
