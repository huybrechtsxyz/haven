# Haven Bootstrap Plan

This document defines a 3-phase rollout so we can deploy minimally first, then add services safely while moving runtime secrets into Infisical.

## Phase 1: Bootstrap

Goal: bring up only the minimum foundation.

Scope:

- Terraform infrastructure provisioning
- Ansible init baseline (OS hardening, Docker, users, directories)
- Caddy
- Infisical (including its DB + Redis)

Why:

- Reduces first-deploy complexity
- Enables Infisical as the runtime secrets source before onboarding other services

Required bootstrap secrets (outside Infisical):

- HETZNER_API_TOKEN
- HETZNER_PRIVATE_KEY
- HETZNER_PUBLIC_KEY
- HETZNER_ROOT_PASSWORD
- TERRAFORM_API_TOKEN (if pipeline/workflow still requires it)
- INFISICAL_AUTH_SECRET
- INFISICAL_ENCRYPTION_KEY
- INFISICAL_POSTGRESQL_PASSWORD (or equivalent DB URI input)

Success criteria:

- Hearth VM/network/firewall created and reachable
- Baseline init playbook completed
- Caddy serves HTTPS endpoints
- Infisical is healthy and accessible at secrets domain

## Phase 2: Hearth Setup

Goal: onboard core Hearth applications using Infisical-managed runtime secrets.

Scope:

- Enable Authentik
- Enable Vaultwarden
- Enable Portainer
- Enable WUD
- Keep Caddy/Infisical from Phase 1

Secret model:

- Runtime app secrets come from Infisical
- Do not add new long-lived app secrets to GitHub environment secrets
- Keep only true bootstrap/infrastructure secrets outside Infisical

Runtime secrets to place in Infisical:

- AUTHENTIK_SECRET_KEY
- AUTHENTIK_POSTGRESQL_PASSWORD
- AUTHENTIK_EMAIL_USERNAME
- AUTHENTIK_EMAIL_PASSWORD
- VAULTWARDEN_ADMIN_TOKEN
- VAULTWARDEN_SSO_CLIENT_SECRET
- WUD_SSO_CLIENT_SECRET
- BORG_PASSPHRASE

Success criteria:

- Authentik login and OIDC flows operational
- Vaultwarden SSO operational
- Portainer reachable via Caddy
- WUD reachable and OIDC-authenticated
- Deploy path no longer depends on GitHub for runtime app credentials

## Phase 3: Forge Setup

Goal: add the workload environment with pull-only secrets access.

Scope:

- Provision Forge resources (VM and/or cluster as defined by platform config)
- Install workload stack
- Integrate External Secrets flow from Infisical

Secret model:

- Forge uses token-based pull from Infisical
- Keep Forge side limited to scoped access (least privilege)

Required Forge bootstrap secret:

- INFISICAL_ESO_TOKEN (scoped to required paths/environments only)

Expected runtime pattern:

- Apps on Forge consume secrets at runtime via Infisical integration
- No broad infrastructure/admin secrets present on Forge

Success criteria:

- Forge resources provisioned
- Workload services healthy
- Secrets consumed from Infisical via scoped token, not duplicated in CI

## Cross-Phase Rules

- Maintain strict bootstrap vs runtime secret separation.
- Normalize secret naming conventions across config, modules, and deployment playbooks.
- Keep generated .env files minimal and phase-specific.
- Rotate bootstrap secrets after first stable deployment where practical.

## Bitwarden Usage Model (Your Case)

If you use one machine identity for GitHub Actions, this model is valid:

- Store CI/CD and runtime automation secrets in Bitwarden Secrets Manager.
- Use one machine account/token for GitHub with least-privilege project access.
- Keep long-lived human credentials in Bitwarden Password Manager.
- Keep MFA seed/recovery material in Password Manager (secure notes or equivalent), not in CI secrets.

Recommended split:

- Secrets Manager:
 	- Infrastructure and deploy secrets used by automation.
 	- App runtime secrets injected into deployments.
 	- Short-lived or rotated tokens used by pipelines.
- Password Manager:
 	- Admin console logins (Hetzner, DNS registrar, cloud consoles).
 	- Emergency/break-glass credentials.
 	- MFA backup codes and recovery information.

Guardrails:

- Do not duplicate the same secret across both products unless it is an intentional break-glass copy.
- Scope the GitHub machine account to only required projects/environments.
- Rotate machine access tokens regularly and after any pipeline or runner incident.
