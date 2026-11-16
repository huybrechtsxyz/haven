# Portainer

> Portainer — container management UI for Hearth's Docker Compose stack.

## Overview

Portainer is a container management tool for Docker (and Kubernetes). It gives you a web dashboard for everything you'd otherwise do with the Docker CLI — start/stop/restart containers, inspect logs and stats in real time, browse and prune images/volumes/networks, and edit or redeploy Compose stacks — without needing shell access to the host. It's an operations/troubleshooting tool, not something end users interact with.

On Haven, Portainer runs as part of the Hearth Docker Compose stack, giving a visual view into the other Hearth services (Authentik, Vaultwarden, WUD, etc.).

Reachable at `https://portainer.huybrechts.xyz`, reverse-proxied by Caddy (`services/hearth/caddy/Caddyfile`) to the container's HTTPS port (`9443`). The container runs with `--http-disabled`, so it only ever serves over its own self-signed TLS cert — Caddy's `reverse_proxy` upstream therefore uses `tls_insecure_skip_verify` (trust is anchored at the public edge, where Caddy terminates the real cert for `portainer.huybrechts.xyz`; the hop from Caddy to the `portainer` container is over the internal Docker network).

## Initial Setup

Portainer bootstraps its own local admin account on first launch — there is no cloud account or SSO involved. 

Portainer stays on local auth, not SSO. Portainer is **intentionally not** wired through Authentik SSO. Portainer exists to check on and recover other containers (including Authentik itself), so it must stay reachable even when Authentik is down, misconfigured, or mid-upgrade, putting it behind the identity provider it may need to fix would defeat that purpose. Portainer uses its own local admin account instead (create it + enable MFA on first login).

As a secondary consideration, Portainer CE (the free edition used here) doesn't support OAuth/OIDC at all. SSO would require upgrading to Portainer Business Edition (free up to 3 nodes / 5 users). Not a blocker either way, since local auth is the deliberate choice regardless of edition.

### Initial Admin Account Setup

1. Browse to `https://portainer.huybrechts.xyz` within 5 minutes of the container's first start (Portainer locks the setup wizard after that window. If missed, the data volume must be wiped and the container restarted to try again)
2. Create the initial admin username and a strong password
3. Enable MFA (TOTP):
   - Log in → user menu (top-right) → **My account**
   - Enable **Two-factor authentication**
   - Scan the QR code with **Bitwarden Authenticator**
   - Confirm with a generated code
4. Store the admin username, password, and TOTP seed/recovery code in **Bitwarden cloud** (not Vaultwarden)

> **Local auth by design.** Portainer intentionally stays on local credentials + TOTP MFA instead of Authentik SSO — it's an admin tool that must remain accessible for diagnosing/recovering the platform even if Authentik itself is down.

### Service Setup

1. Connect to the local Docker environment (auto-detected via the mounted `/var/run/docker.sock`) — no additional environment needs to be added
2. Review the **Home** dashboard — it should list the Hearth stack's containers (`caddy`, `authentik-server`, `authentik-worker`, `authentik-db`, `authentik-redis`, `vaultwarden`, `portainer`, `wud`, …)
3. Under **Stacks**, confirm the Compose stack is visible (read-only view unless Portainer itself manages the deploy — Haven deploys via the pipeline/Ansible, not through Portainer's stack editor)
4. Optional: create additional restricted users/teams if more than one admin needs access, each with their own TOTP MFA

### Verification checklist

- [ ] `https://portainer.huybrechts.xyz` loads and presents the login page (not the first-run setup wizard)
- [ ] Admin login works with MFA prompt
- [ ] Home dashboard lists all running Hearth containers
- [ ] Credentials + TOTP recovery code stored in Bitwarden cloud
