# haven

**Haven** is a self-hosted family platform running on Hetzner Cloud. 

Deployments target a **Hearth** VPS for identity management (Authentik), password management (Vaultwarden), reverse proxy (Caddy), and supporting services, with a **Forge** VPS for media workloads (Immich, Jellyfin).

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

Follow [guide.md](./guide.md) for the full deployment walkthrough — zero to running:

1. Prerequisites and tooling
2. Secrets and credentials
3. DNS and domain setup
4. Infrastructure provisioning (`deploy-infra.yml`)
5. Hearth deployment (`deploy-hearth-init.yml` → `deploy-hearth-config.yml` → `deploy-hearth-deploy.yml`)
6. Forge deployment (`deploy-forge.yml`)

---

## What's included

- **Docker Compose stack on Hearth** — Authentik (server + worker + Redis + PostgreSQL), Vaultwarden, Caddy, Portainer, WUD
- **k3s cluster on Forge** — Immich, Jellyfin, Gatus
- **Cloud services** — Bitwarden Cloud (deployment credentials), Infisical Cloud (app secrets), Terraform Cloud (state)
- **BorgBackup to Hetzner Storage Box** — daily encrypted backups, `repokey-blake2`, separate repos for Hearth and Forge
- **Independent GitHub Actions workflows** — `deploy-infra.yml`, `deploy-hearth-init.yml` / `deploy-hearth-config.yml` / `deploy-hearth-deploy.yml`, `deploy-forge.yml`
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

---

## Backups

BorgBackup runs daily at 02:00 UTC on Hearth, targeting `{STORAGEBOX_SUBACCOUNT_HEARTH}@{STORAGEBOX_HOST}:./hearth` over SSH port 23 with `repokey-blake2` encryption. Retention: 7 daily, 4 weekly, 6 monthly.

See [backup.md](./backup.md) for restore procedures and disaster recovery.

---

## Documentation

| Document                                   | Contents                                                                      |
| ------------------------------------------ | ----------------------------------------------------------------------------- |
| [guide.md](./guide.md)                     | Full deployment guide — zero to running                                       |
| [setup-cloud.md](./setup-cloud.md)         | Cloud services setup (Bitwarden deployment creds, Infisical, Terraform Cloud) |
| [backup.md](./backup.md)                   | Backup and disaster recovery                                                  |
| [authentik.md](./authentik.md)             | Authentik SSO setup                                                           |
| [bitwarden.md](./bitwarden.md)             | Vaultwarden setup                                                             |
| [portainer.md](./portainer.md)             | Portainer setup                                                               |
| [borgbackup.md](./borgbackup.md)           | BorgBackup details and manual ops                                             |
| [domains.md](./domains.md)                 | DNS and domain configuration                                                  |
| [hetzner.md](./hetzner.md)                 | Hetzner Cloud setup                                                           |
| [terraform.md](./terraform.md)             | Terraform configuration                                                       |
| [healthchecks-io.md](./healthchecks-io.md) | Backup monitoring                                                             |

---

## License

Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See [LICENSE](../LICENSE).
