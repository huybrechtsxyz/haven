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
├── forge (CPX41 — k3s)                          ← Workload: Immich, Jellyfin, Gatus, apps
│   └── Services: Photos, Media Streaming, Health Dashboard, Home-grown Apps
│
├── storage box (BX11, 1 TB)                     ← Tier 1 Backups: BorgBackup (encrypted)
│   └── NFS mount for Jellyfin media library
│
├── object storage (S3, eu-central, 4 buckets)   ← Immich originals, media overflow, archives
│   └── haven-{photos, media, archive, docs}
│
├── Infomaniak kSuite (Switzerland)              ← Email, Calendar, Contacts, Files, Docs
│   └── Tier 2 backups: daily rclone sync to kDrive
│
└── Cloud services (free tier)                   ← Bootstrap + secrets + state
    ├── Bitwarden Cloud  — deployment credentials (API keys, SSH keys)
    ├── Infisical Cloud  — runtime application secrets
    ├── Terraform Cloud  — remote state backend
    └── GitHub           — repo + GitHub Actions CI/CD
```

### Deployment Workflow

Haven uses **three independent GitHub Actions workflows** for independent scheduling and rapid iteration:

| Workflow            | Purpose                                      | Frequency   | When to run                  |
| ------------------- | -------------------------------------------- | ----------- | ---------------------------- |
| `deploy-infra.yml`  | Terraform + S3 provisioning                  | Once (rare) | After infrastructure changes |
| `deploy-hearth.yml` | Core VPS init/config/deploy (Docker Compose) | On-demand   | After service config changes |
| `deploy-forge.yml`  | Workload VPS init/config/deploy (k3s)        | On-demand   | After app/chart updates      |

**Typical deployment order:**

1. Run `deploy-infra.yml` once (Terraform + S3 buckets)
2. Configure DNS at INWX
3. Run `deploy-hearth.yml` for core services
4. Run `deploy-forge.yml` for workload apps

---

## Deployment Phases

| Phase              | Guide                                  | Contents                                                  |
| ------------------ | -------------------------------------- | --------------------------------------------------------- |
| **Prerequisites**  | [prerequisites.md](prerequisites.md)   | Accounts, MFA, tools — complete before deploying anything |
| **Domains**        | [domains.md](domains.md)               | Domain registration, DNS records, email setup             |
| **Setup**          | [setup.md](setup.md)                   | Initial setup of cloud services, secrets, and credentials |
| **Infrastructure** | [infrastructure.md](infrastructure.md) | Terraform + S3 buckets + SSH keys + DNS                   |
| **Haven Hearth**   | [hearth.md](hearth.md)                 | Core VPS: Caddy, Authentik, Vaultwarden                   |


## TODO

| **Haven Forge**    | [forge.md](forge.md) *(coming soon)*                   | Workload VPS: k3s, Immich, Jellyfin, Gatus                                  |
| **Verify**         | [verify.md](verify.md) *(coming soon)*                  | Post-deploy smoke tests + verification checklist                            |
| **Migration**      | [migration.md](migration.md) *(coming soon)*                     | Migrating from Google Workspace + Bitwarden                                 |
