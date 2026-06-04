# Phase 5 — Service Initial Setup

> [← Phase 4](phase-4-hearth-deploy.md) | [Next: Phase 6 — Backups →](phase-6-backups.md)

One-time manual setup for each service after containers are running.
These steps create the admin accounts and configure each service for first use.

**Automated:** Nothing — these are one-time interactive steps per service.  
**Estimated time:** 30–45 minutes.

---

## 5.1 — Authentik

URL: `https://auth.huybrechts.xyz`

### Create admin account

1. Navigate to `https://auth.huybrechts.xyz/if/flow/initial-setup/`
2. Enter your admin **email** and **password**
3. Submit — you are now logged in as the Authentik admin

> This page is only available once (until an admin account exists). After the first account is created, it redirects to the normal login page.

### Recommended next steps

- Enable 2FA: Admin → Users → your user → MFA Devices → Add TOTP
- Explore: Admin → System → Overview to confirm all tasks are processing

---

## 5.2 — Vaultwarden

URL: `https://vault.huybrechts.xyz`

Vaultwarden disables user registration by default. You must enable it temporarily via the admin panel.

### Enable registration and create accounts

1. Navigate to `https://vault.huybrechts.xyz/admin`
2. Enter your `VAULTWARDEN_ADMIN_TOKEN` (from GitHub Secrets)
3. Go to **General Settings** → under **Registration** → enable **"Allow new signups"**
4. Click **Save**

5. Navigate to `https://vault.huybrechts.xyz/#/register`
6. Create each family account (email + password)
7. Repeat for all users who need a vault

### Disable registration

8. Return to `https://vault.huybrechts.xyz/admin`
9. Disable **"Allow new signups"**
10. Click **Save**

### Configure Bitwarden clients

Users can connect existing Bitwarden apps to the self-hosted vault:
- Open Bitwarden app → Settings → Server URL → `https://vault.huybrechts.xyz`
- Log in with the email/password created above

### Import existing passwords

To import from a Bitwarden JSON export:
1. Log in to the web vault at `https://vault.huybrechts.xyz`
2. Tools → Import Data → Bitwarden (json) format
3. Select your export file

---

## 5.3 — Infisical

URL: `https://secrets.huybrechts.xyz`

### Create admin account

1. Navigate to `https://secrets.huybrechts.xyz`
2. The first-run signup page appears
3. Enter email, name, and password to create the admin account
4. Submit — you are now logged in as the Infisical admin

> If the page does not show a signup form but asks for login credentials, the container may have initialized with a default admin. Check the Infisical documentation for your version.

### Create projects and environments

After account creation:
1. Create a new project (e.g., `haven`)
2. Add environments: `production`, `staging`
3. Add secrets for each service as needed

> Infisical will show a warning `connect ECONNREFUSED 127.0.0.1:587` in logs — this is because SMTP is not configured. Email features are disabled but all other functionality works normally.

---

## Summary of credentials to store

After completing all setups, store these in Vaultwarden:

| Service | What to store |
|---------|--------------|
| Authentik | Admin email + password + TOTP seed |
| Vaultwarden | Admin token + master passwords |
| Infisical | Admin email + password |
| Hetzner | API token, SSH key pair |
| INWX | Account credentials |
| Terraform Cloud | API token |
| GitHub | Personal access token (if used) |

---

## Checklist

- [ ] Authentik: admin account created at `/if/flow/initial-setup/`
- [ ] Authentik: 2FA enabled for admin
- [ ] Vaultwarden: admin panel accessible via `/admin`
- [ ] Vaultwarden: family accounts created
- [ ] Vaultwarden: registration disabled again
- [ ] Vaultwarden: Bitwarden clients reconfigured to `vault.huybrechts.xyz`
- [ ] Infisical: admin account created
- [ ] All credentials stored in Vaultwarden
