# haven

**Haven** is a self-hosted family platform running on Hetzner Cloud. It deploys identity management (Authentik), password management (Vaultwarden), secrets management (Infisical), and a reverse proxy (Caddy) to a **Hearth** VPS, with a **Forge** VPS for media workloads (Immich, Jellyfin).

All infrastructure is defined in YAML, built with `strata`, provisioned with Terraform, and deployed with Ansible via GitHub Actions.

---

## Getting started

Follow [guide.md](./guide.md) for the full deployment walkthrough — zero to running:

1. Prerequisites and tooling
2. Secrets and credentials
3. DNS and domain setup
4. Infrastructure provisioning (`deploy-infra.yml`)
5. Hearth deployment (`deploy-hearth.yml`)
6. Forge deployment (`deploy-forge.yml`)

---

## What's included

- **9-container Docker Compose stack on Hearth** — Authentik (server + worker + Redis + PostgreSQL), Vaultwarden, Infisical (backend + Redis + PostgreSQL), Caddy
- **k3s cluster on Forge** — Immich, Jellyfin, Gatus *(initialisation complete — workload deployment in progress)*
- **BorgBackup to Hetzner Storage Box** — daily encrypted backups, `repokey-blake2`, separate repos for Hearth and Forge
- **Three independent GitHub Actions workflows** — `deploy-infra.yml`, `deploy-hearth.yml`, `deploy-forge.yml`
- **No lock-in** — build output is plain Terraform + Ansible

---

## Services (Hearth)

| Service     | URL                          | Purpose                                 |
| ----------- | ---------------------------- | --------------------------------------- |
| Authentik   | `https://auth.{domain}`      | SSO / identity provider                 |
| Vaultwarden | `https://vault.{domain}`     | Password manager (Bitwarden-compatible) |
| Infisical   | `https://secrets.{domain}`   | Secrets management                      |
| Portainer   | `https://portainer.{domain}` | Docker container management             |
| WUD         | `https://wud.{domain}`       | Container update notifications          |
| Caddy       | `:443` (all subdomains)      | Reverse proxy + automatic TLS           |

---

## Backups

BorgBackup runs daily at 02:00 UTC on Hearth, targeting `{STORAGEBOX_SUBACCOUNT_HEARTH}@{STORAGEBOX_HOST}:./hearth` over SSH port 23 with `repokey-blake2` encryption. Retention: 7 daily, 4 weekly, 6 monthly.

See [backup.md](./backup.md) for restore procedures and disaster recovery.

---

## Documentation

| Document                                   | Contents                                |
| ------------------------------------------ | --------------------------------------- |
| [guide.md](./guide.md)                     | Full deployment guide — zero to running |
| [backup.md](./backup.md)                   | Backup and disaster recovery            |
| [authentik.md](./authentik.md)             | Authentik SSO setup                     |
| [bitwarden.md](./bitwarden.md)             | Vaultwarden setup                       |
| [infisical.md](./infisical.md)             | Infisical setup                         |
| [portainer.md](./portainer.md)             | Portainer setup                         |
| [borgbackup.md](./borgbackup.md)           | BorgBackup details and manual ops       |
| [domains.md](./domains.md)                 | DNS and domain configuration            |
| [hetzner.md](./hetzner.md)                 | Hetzner Cloud setup                     |
| [terraform.md](./terraform.md)             | Terraform configuration                 |
| [healthchecks-io.md](./healthchecks-io.md) | Backup monitoring                       |

---

## License

Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See [LICENSE](../LICENSE).


