# Squad Team

> haven

## Coordinator

| Name | Role | Notes |
|------|------|-------|
| Squad | Coordinator | Routes work, enforces handoffs and reviewer gates. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Mal | 🏗️ Lead & Architect | .squad/agents/mal/charter.md | active |
| Kaylee | 🔧 Infrastructure Dev | .squad/agents/kaylee/charter.md | active |
| Simon | ⚙️ Platform Dev | .squad/agents/simon/charter.md | active |
| Zoe | 🧪 QA & Migration | .squad/agents/zoe/charter.md | active |
| Scribe | 📋 *(silent)* | .squad/agents/scribe/charter.md | active |
| Ralph | 🔄 *(monitor)* | .squad/agents/ralph/charter.md | active |

## Project Context

- **Project:** Haven — family IT platform for 5 users (Huybrechts family)
- **Owner:** Vincent Huybrechts
- **Created:** 2026-05-29
- **Universe:** Firefly
- **Stack:** Hetzner VPS — Hearth (CX22, Docker Compose) + Forge (CPX41, k3s) + Storage Box (BX11)
- **Services:** Caddy, Authentik, Vaultwarden, Infisical (Hearth); Immich, Gatus (Forge)
- **IaC:** strata CLI, OpenTofu/Terraform, Ansible, Helm
- **Config repo:** YAML files in `stack/`, `deploy/`, `envs/`
- **Migration:** Google Workspace + Kamatera VPS → Infomaniak kSuite + Hetzner

## Issue Source

- **Repository:** *(not yet connected)*
- **Filters:** squad labels
