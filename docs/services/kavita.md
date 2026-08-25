# Kavita

> Kavita — PDF/EPUB/comic library server, self-hosted on Forge (k3s).

## Overview

Kavita runs on **Forge** (Hetzner CPX41, k3s), in the shared `documents` Kubernetes namespace alongside Nextcloud. See [Forge](../guides/forge.md) for the node-level overview and [Nextcloud](./nextcloud.md) for the sibling app it shares files with.

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once, `rclone-mount` (system namespace) must be running so `/mnt/haven-docs` exists on the host, and a DNS A record for `books.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## What gets deployed

| Item      | Value                                                                                                                                              |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image     | `lscr.io/linuxserver/kavita` (LinuxServer.io's actively-maintained image) — **tag not yet verified against a live source, see "Still open" below** |
| Namespace | `documents` (Kubernetes), module file `config/forge/modules/kavita.yaml`                                                                           |
| Ingress   | Traefik (`className: traefik`), host `books.{domain}`, no TLS yet                                                                                  |

No official Helm chart exists for Kavita (confirmed via a code search across the `Kareadita` GitHub org — no results) — deployed via a local chart at `services/forge/kavita/`.

---

## Storage — shares `haven-docs` with Nextcloud

Kavita reads from `/mnt/haven-docs/games` (hostPath, **read-only**) — a subpath of the same tree `rclone-mount` (see [forge.md](../guides/forge.md#rclone-mount--shared-filesystem-bridge-for-haven-docs)) publishes from the `haven-docs` S3 bucket. Kavita never renames or reorganizes what it finds — it only indexes/scans — which is exactly why it's safe to share the same files Nextcloud also organizes (unlike Paperless-ngx, which takes ownership of ingested documents and would need its own separate bucket).

Kavita's own config/database is separate, local-disk storage (`persistence.config`, `local-path` PVC, 5Gi) — not part of the shared tree.

---

## SSO

Kavita supports OIDC natively per its own project README ("Ability to manage users with rich Role-based management... OIDC, etc"), but the exact settings/UI flow were not verified when this module was authored. **Not wired up yet** — same category of follow-up as Nextcloud's `user_oidc` setup and Jellyfin's SSO plugin registration.

---

## Verification checklist

- [ ] `http://books.{domain}` — Kavita loads (plain HTTP until TLS is wired up)
- [ ] Library scan picks up files under `/mnt/haven-docs/games`
- [ ] Confirm the actual current LinuxServer.io image tag before first deploy
- [ ] Authentik SSO wired up (once prioritized)

---

## Still open

- No TLS/cert-manager on Forge yet — Kavita is HTTP-only for now
- `forge-deploy.yml` (the Ansible playbook that would run `helm upgrade`) doesn't exist yet
- Image tag needs a live-source verification pass (LinuxServer.io's docs site and the Kavita wiki both failed to render via automated fetch when this module was authored — used well-established general knowledge instead of a live-verified source)
- OIDC/SSO not configured
