# haven

**Haven** is a self-hosted family platform running on Hetzner Cloud. 

Deployments target a **Hearth** VPS for identity management (Authentik), password management (Vaultwarden), reverse proxy (Caddy), and supporting services, with a **Forge** VPS for family apps (Immich, Jellyfin, Nextcloud, Kavita).

It uses free cloud services to eliminate the bootstrap problem:

- **Deployment credentials** → [Bitwarden Cloud](https://bitwarden.com/products/cloud/) (free tier)
- **Application secrets** → [Infisical Cloud](https://infisical.com/)
- **Terraform state** → [Terraform Cloud](https://cloud.hashicorp.com/)
- **Repositories and CI/CD** → GitHub Actions

**Note** for Day-to-day passwords we rely on → [Vaultwarden](https://github.com/dani-garcia/vaultwarden) (self-hosted)

This approach **eliminates the bootstrap problem** — deployment credentials are stored in Bitwarden Cloud before infrastructure exists, allowing you to bootstrap from nothing.

All infrastructure is defined in YAML, built with `strata`, provisioned with Terraform, and deployed with Ansible.

---

## Getting started

Follow [guides/index.md](./guides/index.md) for the full deployment walkthrough — zero to running:

1. [Prerequisites and tooling](./guides/prerequisites.md)
2. [Secrets and credentials](./guides/setup.md)
3. [DNS and domain setup](./guides/domains.md)
4. [Infrastructure provisioning](./guides/infrastructure.md) (`deploy-infra.yml`)
5. Hearth deployment — see [guides/hearth.md](./guides/hearth.md) (`deploy-hearth-init.yml` → `deploy-hearth-config.yml` → `deploy-hearth-deploy.yml`)
6. Forge deployment — see [guides/forge.md](./guides/forge.md) (`deploy-forge-init.yml` → `deploy-forge-config.yml` → `deploy-forge-deploy.yml`)
7. [Family onboarding](./guides/onboarding.md)

---

## What's included

- **Docker Compose stack on Hearth** — Authentik (server + worker + Redis + PostgreSQL), Vaultwarden, Caddy, Portainer, WUD
- **k3s cluster on Forge** — Immich (photos), Jellyfin (media streaming), Nextcloud (document archive), Kavita (EPUB/PDF library)
- **Cloud services** — Bitwarden Cloud (deployment credentials), Infisical Cloud (app secrets), Terraform Cloud (state)
- **Two Hetzner Storage Boxes** — `haven-backup` (Hearth + Forge BorgBackup repos, `repokey-blake2` encrypted) and `haven-data` (Immich/Jellyfin/Nextcloud/Kavita live data via SMB, split into `media` and `docs` sub-accounts) — kept separate so backups and live media/documents scale independently
- **Independent GitHub Actions workflows** — `deploy-infra.yml`, `deploy-hearth-init.yml` / `deploy-hearth-config.yml` / `deploy-hearth-deploy.yml`, `deploy-forge-init.yml` / `deploy-forge-config.yml` / `deploy-forge-deploy.yml`
- **No lock-in** — build output is plain Terraform + Ansible

---

## Services

### Bootstrap services

| Service         | Purpose                            |
| --------------- | ---------------------------------- |
| Bitwarden Cloud | Deployment credentials (bootstrap) |
| GitHub Actions  | CI/CD for deployments              |
| Infisical Cloud | Application secrets management     |
| Terraform Cloud | Remote state management            |

### Hearth services

| Service     | URL                          | Purpose                                 |
| ----------- | ---------------------------- | --------------------------------------- |
| Authentik   | `https://auth.{domain}`      | SSO / identity provider                 |
| Vaultwarden | `https://vault.{domain}`     | Password manager (Bitwarden-compatible) |
| Caddy       | `:443` (all subdomains)      | Reverse proxy + automatic TLS           |
| Portainer   | `https://portainer.{domain}` | Docker container management             |
| WUD         | `https://wud.{domain}`       | Container update notifications          |

### Forge services

| Service   | URL                       | Purpose                         |
| --------- | ------------------------- | ------------------------------- |
| Immich    | `https://photos.{domain}` | Photo/video library             |
| Jellyfin  | `https://media.{domain}`  | Media streaming                 |
| Nextcloud | `https://docs.{domain}`   | Document archive/browsing layer |
| Kavita    | `https://books.{domain}`  | EPUB/PDF library                |

---

## Backups

BorgBackup runs daily at 02:00 UTC on both Hearth and Forge, targeting each node's own sub-account/repo on the dedicated `haven-backup` Storage Box over SSH port 23 with `repokey-blake2` encryption. Retention: 7 daily, 4 weekly, 6 monthly.

Live Immich/Jellyfin/Nextcloud/Kavita data lives on a **separate** Storage Box (`haven-data`, split into `media` and `docs` sub-accounts) — none of these apps have native S3 support, so a plain filesystem mount is used for all of them rather than object storage. Keeping backups and live data on separate boxes lets each scale to its own cheapest tier independently (Storage Box billing is per-box/fixed-tier). See [architecture.md](./architecture.md) for the full storage layout.

See [guides/hearth.md](./guides/hearth.md) and [guides/forge.md](./guides/forge.md) for restore procedures and disaster recovery.

---

## Documentation

| Document                                                     | Contents                                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------------------- |
| [architecture.md](./architecture.md)                         | System topology, component inventory, data durability model               |
| [design.md](./design.md)                                     | Design rationale, domain/email layout, security posture, monthly costs    |
| [guides/index.md](./guides/index.md)                         | Full deployment guide — zero to running                                   |
| [guides/prerequisites.md](./guides/prerequisites.md)         | Prerequisites and tooling                                                 |
| [guides/setup.md](./guides/setup.md)                         | Secrets and credential management (Bitwarden, Infisical, Terraform Cloud) |
| [guides/domains.md](./guides/domains.md)                     | DNS and domain configuration                                              |
| [guides/infrastructure.md](./guides/infrastructure.md)       | Infrastructure provisioning                                               |
| [guides/hearth.md](./guides/hearth.md)                       | Hearth deployment — Authentik, Vaultwarden, Portainer, WUD, BorgBackup    |
| [guides/forge.md](./guides/forge.md)                         | Forge deployment — Immich, Jellyfin, Nextcloud, Kavita, Storage Box       |
| [guides/onboarding.md](./guides/onboarding.md)               | Family onboarding                                                         |
| [services/bitwarden.md](./services/bitwarden.md)             | Bitwarden Cloud + Vaultwarden setup                                       |
| [services/infisical.md](./services/infisical.md)             | Infisical Cloud setup                                                     |
| [services/terraform.md](./services/terraform.md)             | Terraform Cloud setup                                                     |
| [services/github.md](./services/github.md)                   | GitHub Actions CI/CD setup                                                |
| [services/hetzner.md](./services/hetzner.md)                 | Hetzner Cloud + Storage Box setup                                         |
| [services/inwx.md](./services/inwx.md)                       | INWX DNS setup                                                            |
| [services/infomaniak.md](./services/infomaniak.md)           | Infomaniak kSuite setup                                                   |
| [services/immich.md](./services/immich.md)                   | Immich service notes                                                      |
| [services/jellyfin.md](./services/jellyfin.md)               | Jellyfin service notes                                                    |
| [services/nextcloud.md](./services/nextcloud.md)             | Nextcloud service notes                                                   |
| [services/kavita.md](./services/kavita.md)                   | Kavita service notes                                                      |
| [services/healthchecks-io.md](./services/healthchecks-io.md) | Backup monitoring                                                         |
| [services/uptimerobot.md](./services/uptimerobot.md)         | Public endpoint monitoring                                                |

---

## License

Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See [LICENSE](../LICENSE).
