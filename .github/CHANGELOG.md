# haven — Changelog

All notable changes to this project are documented in this file.

---

## [Unreleased]

_Changes not yet deployed to production._

---

## [0.1.0] — 2026-06-04

_Initial working deployment. All services operational on Hetzner Cloud._

### Added

- **Infrastructure** — Hetzner Cloud CX23 VPS provisioned via Terraform (HCloud provider). Cloud firewall restricting SSH to private network by default; temporarily opened per-run by the CI pipeline.

- **Server bootstrap** (`deploy/ansible-init/hearth-init.yml`) — One-time Ansible playbook: system packages, `haven` service account, Docker CE, hardened SSH, fail2ban, unattended-upgrades, BorgBackup SSH key generation, optional Borg repo initialisation.

- **Configuration enforcement** (`deploy/ansible-config/hearth-config.yml`) — Idempotent playbook run on every deploy: BorgBackup script deployment, passphrase file (mode `0400`), daily cron job, package state, SSH config drift correction.

- **Service deployment** (`deploy/ansible-deploy/hearth-deploy.yml`) — All 9 Docker Compose containers deployed and operational:
  - Authentik: server + worker + Redis + PostgreSQL
  - Vaultwarden
  - Infisical: backend + Redis + PostgreSQL
  - Caddy (reverse proxy, automatic TLS)

- **TLS** — Let's Encrypt production certificates via Caddy ACME for all three service domains.

- **BorgBackup automation** — Jinja2 backup script template, passphrase file (mode `0400`), daily cron at 02:00 UTC, configurable retention (7 daily / 4 weekly / 6 monthly), `backup_before_deploy` flag in CI pipeline.

- **GitHub Actions pipeline** (`.github/workflows/deploy.yml`) — `workflow_dispatch` with `run_init`, `run_config`, `run_deploy`, `backup_before_deploy` inputs. Temporary Hetzner firewall SSH rule opened/closed per run. Secrets injected via GitHub `production` environment.

- **strata integration** — Build and deploy stages use `xyz-strata` CLI to generate Terraform artifacts from YAML config files in `config/`.

- **Operations documentation** (`docs/haven/`) — 7-phase guide covering prerequisites, DNS, infrastructure provisioning, server initialisation, service deployment, first-run service setup, and BorgBackup configuration.

<!--
To document a new change:
- Add entries under [Unreleased] as you work.
- When deploying to production, move [Unreleased] entries into a new ## [x.y.z] section with today's date.
-->
