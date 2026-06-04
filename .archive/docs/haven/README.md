# Haven — Operations Guide

> Platform: Hetzner CX23 · Docker Compose · Caddy · Authentik · Vaultwarden · Infisical  
> Repo: `huybrechtsxyz/haven` · Branch: `haven-initial`  
> Design reference: [hosting-design.md](../design/hosting-design.md)

---

## What is Haven?

Haven is the Hearth VPS — a self-hosted family platform running on a Hetzner CX23.
It provides identity, secrets, and password management for all Huybrechts family services.

```
Internet → Caddy (TLS) → auth.huybrechts.xyz    → Authentik  (SSO / identity)
                       → vault.huybrechts.xyz   → Vaultwarden (passwords)
                       → secrets.huybrechts.xyz → Infisical   (secrets & config)
```

---

## Architecture at a glance

| Layer            | Component                            | Managed by                                 |
| ---------------- | ------------------------------------ | ------------------------------------------ |
| DNS              | INWX                                 | Manual (once)                              |
| Infrastructure   | Hetzner CX23 + firewall + network    | **strata / Terraform**                     |
| Server bootstrap | Docker, haven user, directories, SSH | **strata / Ansible hearth-init**           |
| Services         | Docker Compose (9 containers)        | **GitHub Actions / Ansible hearth-deploy** |
| TLS certificates | Caddy + Let's Encrypt                | Automatic                                  |
| Admin accounts   | Authentik, Infisical, Vaultwarden    | **Manual (once per service)**              |
| Backups          | BorgBackup → Hetzner Storage Box     | Semi-automated (cron + manual key)         |

---

## What strata + GitHub Actions automate

| Task                                             | Automated?                                 |
| ------------------------------------------------ | ------------------------------------------ |
| Provision Hetzner VPS, firewall, private network | ✅ Terraform via strata build               |
| Install Docker, create `haven` user, harden SSH  | ✅ Ansible `hearth-init`                    |
| Deploy docker-compose.yml, Caddyfile, `.env`     | ✅ Ansible `hearth-deploy` (GitHub Actions) |
| Pull container images, start 9 services          | ✅ docker compose up -d                     |
| Obtain & renew Let's Encrypt certificates        | ✅ Caddy ACME                               |
| Fix authentik media directory ownership          | ✅ hearth-deploy                            |
| Restart containers after permission fixes        | ✅ hearth-deploy                            |

---

## What requires manual steps

| Task                                                      | When        | Where                                        |
| --------------------------------------------------------- | ----------- | -------------------------------------------- |
| Order Hetzner Storage Box                                 | Once        | Hetzner Robot (no API)                       |
| Create DNS A records at INWX                              | Once per IP | INWX console                                 |
| **Do NOT enable DNSSEC at INWX**                          | Always      | See Phase 1 — breaks Let's Encrypt           |
| Create GitHub Secrets (tokens, passwords, keys)           | Once        | GitHub repo Settings                         |
| Generate service secrets (`openssl rand`)                 | Once        | Local workstation                            |
| Create Authentik admin account                            | Once        | `auth.huybrechts.xyz/if/flow/initial-setup/` |
| Create Infisical admin account                            | Once        | `secrets.huybrechts.xyz`                     |
| Enable Vaultwarden registration, create accounts, disable | Once        | `vault.huybrechts.xyz/admin`                 |

---

## Current status (June 2026)

| Phase | Description                              | Status        |
| ----- | ---------------------------------------- | ------------- |
| 0     | Prerequisites                            | ✅ Complete    |
| 1     | DNS & domain at INWX                     | ✅ Complete    |
| 2     | Hetzner infrastructure                   | ✅ Complete    |
| 3     | Server initialization (hearth-init)      | ✅ Complete    |
| 4     | Core services deployment (hearth-deploy) | ✅ Complete    |
| 5     | Service initial setup                    | ✅ Complete    |
| 6     | Backups (BorgBackup)                     | ⏳ In progress |

---

## Phase guides

| File                                                   | Description                                     |
| ------------------------------------------------------ | ----------------------------------------------- |
| [**deploy.md**](deploy.md)                             | **Single-page deployment runbook (start here)** |
| [phase-0-prerequisites.md](phase-0-prerequisites.md)   | Tools, accounts, SSH keys, GitHub Secrets       |
| [phase-1-dns-domain.md](phase-1-dns-domain.md)         | INWX DNS setup, A records, DNSSEC warning       |
| [phase-2-infrastructure.md](phase-2-infrastructure.md) | strata build + Terraform provisioning           |
| [phase-3-hearth-init.md](phase-3-hearth-init.md)       | Ansible server bootstrap                        |
| [phase-4-hearth-deploy.md](phase-4-hearth-deploy.md)   | GitHub Actions deployment, all 9 containers     |
| [phase-5-service-setup.md](phase-5-service-setup.md)   | Admin accounts, first-run setup per service     |
| [phase-6-backups.md](phase-6-backups.md)               | BorgBackup to Hetzner Storage Box               |

---

## Key facts

| Item                | Value                                     |
| ------------------- | ----------------------------------------- |
| Server IP           | `91.98.78.36`                             |
| Install path        | `/opt/haven`                              |
| Docker project name | `haven`                                   |
| Compose file        | `/opt/haven/etc/docker-compose.yml`       |
| Env file            | `/opt/haven/etc/.env`                     |
| Caddy certs         | `/opt/haven/var/certs/caddy/`             |
| TLS valid until     | September 2, 2026 (auto-renewed by Caddy) |
| Git branch          | `haven-initial`                           |
| strata version      | `xyz-strata==0.0.9`                       |
