# haven

haven is the **infrastructure and application configuration** for a self-hosted family platform. It deploys a Docker Compose stack to a Hetzner VPS — Authentik (SSO), Vaultwarden (passwords), Infisical (secrets), and Caddy (reverse proxy + auto-TLS) — managed entirely through GitHub Actions pipelines.

All infrastructure is defined in YAML, built with `strata`, provisioned with Terraform, and deployed with Ansible.

## Table of Contents

- [haven](#haven)
  - [Table of Contents](#table-of-contents)
  - [Key Features](#key-features)
  - [Architecture](#architecture)
  - [Prerequisites](#prerequisites)
  - [Quick Start](#quick-start)
  - [Configuration](#configuration)
  - [Deployment Workflow](#deployment-workflow)
  - [Services](#services)
  - [Backups](#backups)
  - [Troubleshooting](#troubleshooting)
  - [Contributing](#contributing)
  - [Security](#security)
  - [License](#license)

---

## Key Features

- **Fully automated deployment** — GitHub Actions pipeline handles init, config, and deploy. No SSH access required from your workstation.
- **Declarative YAML configuration** — All infrastructure defined in Kubernetes-style YAML (`apiVersion`, `kind`, `meta`, `spec`) via `strata`.
- **9 containers, one stack** — Authentik (server + worker + Redis + PostgreSQL), Vaultwarden, Infisical (backend + Redis + PostgreSQL), Caddy.
- **Auto-TLS** — Caddy obtains and renews Let's Encrypt certificates automatically.
- **Off-site encrypted backups** — BorgBackup to Hetzner Storage Box, daily cron, repokey-blake2 encryption.
- **Idempotent re-runs** — Every playbook is safe to re-run. Init detects existing state, config enforces desired state, deploy is declarative.
- **No lock-in** — Build output is plain Terraform + Ansible. Copy it, run it yourself.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────┐
│  Hetzner Cloud — CX23 VPS (Ubuntu 24.04)                │
│  IP: 91.98.78.36                                        │
│                                                         │
│  ┌──────────────────────────────────────────────┐       │
│  │  Docker Compose (project: haven)             │       │
│  │                                              │       │
│  │  Caddy ─────────── :443 reverse proxy        │       │
│  │  Authentik Server ─ auth.huybrechts.xyz      │       │
│  │  Authentik Worker                            │       │
│  │  Authentik Redis                             │       │
│  │  Authentik PostgreSQL                        │       │
│  │  Vaultwarden ────── vault.huybrechts.xyz     │       │
│  │  Infisical Backend ─ secrets.huybrechts.xyz  │       │
│  │  Infisical Redis                             │       │
│  │  Infisical PostgreSQL                        │       │
│  └──────────────────────────────────────────────┘       │
│                                                         │
│  BorgBackup → u604953.your-storagebox.de (BX11, 1 TB)   │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Tool                                                 | Version | Purpose                              |
| ---------------------------------------------------- | ------- | ------------------------------------ |
| [strata](https://github.com/huybrechtsxyz/strata)    | ≥ 0.0.9 | Build deployment artifacts from YAML |
| [OpenTofu](https://opentofu.org/docs/intro/install/) | ≥ 1.6   | Infrastructure provisioning          |
| [Ansible](https://docs.ansible.com/)                 | ≥ 2.14  | Server configuration + deployment    |
| [GitHub CLI](https://cli.github.com/)                | latest  | Workflow dispatch                    |
| Git                                                  | any     | Version control                      |

Install:

```powershell
pip install xyz-strata==0.0.9 ansible-core
winget install GitHub.cli Git.Git
# OpenTofu: choco install opentofu
```

**External accounts:** Hetzner Cloud, Hetzner Robot, Terraform Cloud, GitHub, INWX.

---

## Quick Start

```bash
# 1. Clone the repo
git clone git@github.com:huybrechtsxyz/haven.git && cd haven

# 2. Build deployment artifacts
strata build run

# 3. Deploy via GitHub Actions
gh workflow run "Deploy - haven" -f run_init=true -f run_config=true -f run_deploy=true
```

> First-time setup requires secrets, DNS, and infrastructure provisioning — see [Deployment Workflow](#deployment-workflow).

---

## Configuration

Platform YAML files follow a Kubernetes-style schema:

```yaml
apiVersion: strata.huybrechts.xyz/v1
kind: deployment
meta:
  name: haven-deploy-prd
  annotations:
    description: Haven production deployment
spec:
  ...
```

| File                           | Purpose                                              |
| ------------------------------ | ---------------------------------------------------- |
| `config/ws-haven.yaml`         | Workspace definition                                 |
| `config/cfg-haven.yaml`        | Platform configuration                               |
| `config/env-haven-prd.yaml`    | Environment overrides                                |
| `config/deploy-haven-prd.yaml` | Deployment manifest                                  |
| `config/dc-hetzner-eu-de.yaml` | Datacenter / provider                                |
| `config/hearth/`               | Server-specific resources (VM, firewall, storagebox) |

---

## Deployment Workflow

The full pipeline runs via GitHub Actions (`Deploy - haven`):

| Step | Pipeline Input               | What happens                                                |
| ---- | ---------------------------- | ----------------------------------------------------------- |
| 1    | *(always)*                   | `strata build` → Terraform `init` → `plan` → `apply`        |
| 2    | `run_init: true`             | Ansible: install Docker, create `haven` user, harden SSH    |
| 3    | `run_config: true`           | Ansible: enforce system config, deploy backup script + cron |
| 4    | `run_deploy: true`           | Ansible: write Compose stack, start all 9 containers        |
| 5    | `backup_before_deploy: true` | Run BorgBackup snapshot before deploying                    |

Additional inputs: `dry_run` (plan only), `configure_borg` (init borg repo on Storage Box), `stage` (limit to specific stage).

Firewall SSH access is opened at the start of the workflow and closed at the end.

---

## Services

| Service     | URL                              | Purpose                                 |
| ----------- | -------------------------------- | --------------------------------------- |
| Authentik   | `https://auth.huybrechts.xyz`    | SSO / identity provider                 |
| Vaultwarden | `https://vault.huybrechts.xyz`   | Password manager (Bitwarden-compatible) |
| Infisical   | `https://secrets.huybrechts.xyz` | Secrets management                      |
| Caddy       | `:443` (all subdomains)          | Reverse proxy + automatic TLS           |

---

## Backups

- **Engine:** BorgBackup with `repokey-blake2` encryption
- **Target:** `hearth-backup@u604953.your-storagebox.de:./hearth` (port 23)
- **Schedule:** Daily at 02:00 UTC via cron
- **Retention:** 7 daily, 4 weekly, 6 monthly
- **Data:** Authentik, Vaultwarden, and Infisical volumes + config
- **Log:** `/var/log/haven-backup.log`

---

## Troubleshooting

| Symptom                           | Likely cause                                   | Fix                                                            |
| --------------------------------- | ---------------------------------------------- | -------------------------------------------------------------- |
| Pipeline hangs on borg tasks      | Storage Box SSH is port 23, not 22             | Ensure `-p 23` in all `BORG_RSH` variables                     |
| Caddy fails to get certificates   | DNS not propagated or DNSSEC enabled           | Check A records resolve; never enable DNSSEC at INWX           |
| Authentik worker crash            | `media/` dir not owned by uid 1000             | Re-run `run_init: true` to fix permissions                     |
| Infisical crash on startup        | `ENCRYPTION_KEY` is 64 chars instead of 32     | Use `token_hex(16)` (= 32 hex chars), not `token_hex(32)`      |
| `Permission denied` on backup     | SSH key not authorized                         | Paste public key in Hetzner Robot → Storage Box → Sub-accounts |
| Services unreachable after deploy | Firewall closed SSH but containers not started | Re-run with `run_deploy: true`                                 |

---

## Contributing

See [CONTRIBUTING.md](../.github/CONTRIBUTING.md) for guidelines.

---

## Security

See [SECURITY.md](../.github/SECURITY.md) for vulnerability reporting.

---

## License

Licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See [LICENSE](../LICENSE).
