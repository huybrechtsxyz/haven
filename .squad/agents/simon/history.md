# Simon — Project History

## Project Context (day-1 seed)

- **Project:** Haven — family IT platform for 5 users (Huybrechts family)
- **Owner:** Vincent Huybrechts
- **Hearth services (Docker Compose on CX22):**
  - Caddy — reverse proxy + automatic TLS (ACME), routes all public subdomains
  - Authentik — SSO/OIDC/2FA for all services; 5 family user accounts
  - Vaultwarden — Bitwarden-compatible password manager; migrating from Bitwarden Team (€15/mo)
  - Infisical — secrets management for apps and CI/CD; ESO integration for k3s
- **Forge services (k3s on CPX41):**
  - Immich — self-hosted Google Photos replacement; auto-upload from family phones
  - Gatus — health dashboard at status.huybrechts.xyz
  - Home-grown apps — future workloads via Helm
- **Subdomains (all proxied via Caddy on Hearth):**
  - auth.huybrechts.xyz → Authentik
  - vault.huybrechts.xyz → Vaultwarden
  - secrets.huybrechts.xyz → Infisical
  - photos.huybrechts.xyz → Immich (proxied to Forge)
  - status.huybrechts.xyz → Gatus (proxied to Forge)
- **OIDC flow:** Authentik is the IdP; Vaultwarden, Immich, Infisical are OIDC relying parties
- **Forge firewall:** inbound HTTP/HTTPS only from Hearth private IP (10.0.0.0/8); k3s API on private only
- **Wave 1 status:** No services deployed yet — Hetzner provisioning is Wave 1 Phase 1.2

## Learnings
