# Haven Deployment Guide

> How to deploy the Haven family platform from zero to running.

This guide walks through the entire deployment process for haven, from setting up free cloud accounts and generating secrets to provisioning infrastructure and configuring services. By following these steps, you will have a fully functional self-hosted platform running on Hetzner infrastructure, with deployment credentials managed in Bitwarden Cloud and application secrets managed in Infisical Cloud — so you can bootstrap from a clean machine with no prior self-hosted infrastructure.

## Overview

**haven** is a self-hosted family platform deployed on Hetzner infrastructure with Swiss-based file services (Infomaniak kSuite). The system is managed entirely through code (IaC) via strata + Terraform + Ansible.

For system architecture, component inventory, and design rationale, see:

- **[architecture.md](../architecture.md)** — System topology, infrastructure specifications, data durability model
- **[design.md](../design.md)** — Design decisions, domain/email layout, security posture, monthly costs

### Quick System Overview

Haven consists of **two independent VPS nodes** (Hearth + Forge) plus off-site backups and Swiss-based file services:

```text
haven (workspace)
├── hearth (CX23 — Docker Compose)               ← Core: Authentik, Vaultwarden, Caddy
│   └── Services: SSO, Passwords, Reverse Proxy
│
├── forge (CPX41 — k3s)                          ← Workload: Immich, Jellyfin, Nextcloud, Kavita, apps
│   └── Services: Photos, Media Streaming, Document Archive, EPUB/PDF Library, Home-grown Apps
│
├── storage box — haven-backup (BX11, 1 TB)      ← Hearth + Forge BorgBackup repos only
│   ├── sub1: Hearth backup (encrypted, daily)
│   └── sub2: Forge backup (encrypted, daily)
│
├── storage box — haven-data (1 TB, separate)    ← All live app data (SMB mounts)
│   ├── media sub-account: Immich + Jellyfin
│   └── docs sub-account: Nextcloud + Kavita
│
├── object storage (S3, eu-central, 3 buckets)   ← Currently unused
│
├── Infomaniak kSuite (Switzerland)              ← Email, Calendar, Contacts, Files, Docs
│   └── Tier 2 backups: daily rclone sync of both Storage Boxes to kDrive
│
└── Cloud services (free tier)                   ← Bootstrap + secrets + state
    ├── Bitwarden Cloud  — deployment credentials (API keys, SSH keys)
    ├── Infisical Cloud  — runtime application secrets
    ├── Terraform Cloud  — remote state backend
    └── GitHub           — repo + GitHub Actions CI/CD
```

### Deployment Workflow

Haven uses **independent GitHub Actions workflows** for independent scheduling and rapid iteration. Hearth is split into three, matching its three Ansible playbooks (one-time bootstrap vs the routine config+deploy pair):

| Workflow                   | Purpose                                             | Frequency                      | When to run                         |
| -------------------------- | --------------------------------------------------- | ------------------------------ | ----------------------------------- |
| `deploy-infra.yml`         | Terraform + S3 provisioning                         | Once (rare)                    | After infrastructure changes        |
| `deploy-hearth-init.yml`   | Core VPS one-time bootstrap                         | Once (rare)                    | New server, or after a full rebuild |
| `deploy-hearth-config.yml` | Core VPS idempotent configuration enforcement       | On-demand (paired with deploy) | After service config changes        |
| `deploy-hearth-deploy.yml` | Core VPS Docker Compose deploy                      | On-demand (paired with config) | After service config changes        |
| `deploy-forge-init.yml`    | Workload VPS one-time bootstrap (k3s, Traefik)      | Once (rare)                    | New server, or after a full rebuild |
| `deploy-forge-config.yml`  | Workload VPS idempotent configuration (LAN routing) | On-demand (paired with deploy) | After config changes                |
| `deploy-forge-deploy.yml`  | Workload VPS k3s Helm app deploy                    | On-demand (paired with config) | After app/chart updates             |

**Typical deployment order:**

1. Run `deploy-infra.yml` once (Terraform + S3 buckets)
2. Configure DNS at INWX
3. Run `deploy-hearth-init.yml` once (first run only), then `deploy-hearth-config.yml` + `deploy-hearth-deploy.yml` for core services
4. Run `deploy-forge-init.yml` once (first run only), then `deploy-forge-config.yml` + `deploy-forge-deploy.yml` for workload apps

---

## Deployment Phases

| Phase              | Guide                                  | Contents                                                            |
| ------------------ | -------------------------------------- | ------------------------------------------------------------------- |
| **Prerequisites**  | [prerequisites.md](prerequisites.md)   | Accounts, MFA, tools — complete before deploying anything           |
| **Domains**        | [domains.md](domains.md)               | Domain registration, DNS records, email setup                       |
| **Setup**          | [setup.md](setup.md)                   | Initial setup of cloud services, secrets, and credentials           |
| **Infrastructure** | [infrastructure.md](infrastructure.md) | Terraform + S3 buckets + SSH keys + DNS                             |
| **Haven Hearth**   | [hearth.md](hearth.md)                 | Core VPS: Caddy, Authentik, Vaultwarden                             |
| **Haven Forge**    | [forge.md](forge.md)                   | Workload VPS: k3s, Traefik, per-app namespaces                      |
| **Onboarding**     | [onboarding.md](onboarding.md)         | Give a family member access — accounts, groups, per-app first login |

Per-app guides (Immich, Jellyfin, Nextcloud, Kavita, and future self-hosted apps) live under [docs/services/](../services/) — linked from [forge.md](forge.md#what-runs-where).
