# Mal — Project History

## Project Context (day-1 seed)

- **Project:** Haven — family IT platform for 5 users (Huybrechts family)
- **Owner:** Vincent Huybrechts
- **Universe:** Firefly
- **Goal:** Replace Google Workspace + Kamatera VPS with Infomaniak kSuite + Hetzner (EU, privacy-first)
- **Architecture decision (2026-05-26):** Solution A selected — Infomaniak kSuite (Swiss) for managed email/files/calendar + two Hetzner VPS nodes
  - **Hearth** (CX22): Docker Compose — Caddy, Authentik, Vaultwarden, Infisical
  - **Forge** (CPX41): k3s — Immich, Gatus, home-grown apps
  - **Storage Box** (BX11): BorgBackup target, separate hardware, same datacenter (nbg1)
- **IaC:** strata CLI (xyz-strata), OpenTofu/Terraform, Ansible, Helm via GitHub Actions
- **Config repo structure:** `stack/` (resources), `deploy/` (deployments), `envs/` (environments)
- **Migration plan:** Two waves — Wave 1 (infra, passwords, photos) while Google Workspace stays active; Wave 2 (email/files/calendar cutover to kSuite)
- **Wave 1 status (2026-05-29):** In progress — domain transfers to INWX initiated, Hetzner not yet provisioned

## Learnings
