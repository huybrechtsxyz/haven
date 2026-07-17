# Haven — Prerequisites

> Before you deploy anything, complete this checklist. All provider accounts, MFA, and tools must be in place before the infrastructure deployment begins.

[← Back to Guide](./index.md)

---

## Step 1 — Required Accounts

Create accounts in this order. Enable MFA immediately after each signup. Store credentials in **Bitwarden cloud**.

| Service         | URL                              | Setup guide                                         | Notes                                   |
| --------------- | -------------------------------- | --------------------------------------------------- | --------------------------------------- |
| Bitwarden       | <https://bitwarden.com>          | [bitwarden.md](./services/bitwarden.md)             | Bootstrap vault — create this first     |
| INWX            | <https://www.inwx.de>            | [inwx.md](./services/inwx.md)                       | Domain registrar + DNS                  |
| GitHub          | <https://github.com>             | [github.md](./services/github.md)                   | Source code + CI/CD pipelines           |
| Hetzner         | <https://console.hetzner.cloud>  | [hetzner.md](./services/hetzner.md)                 | VPS provisioning + Storage Box          |
| Infisical Cloud | <https://app.infisical.com>      | [infisical.md](./services/infisical.md)             | Runtime application secrets             |
| Terraform Cloud | <https://app.terraform.io>       | [terraform.md](./services/terraform.md)             | Remote state backend                    |
| Infomaniak      | <https://manager.infomaniak.com> | [infomaniak.md](./services/infomaniak.md)           | Email, kDrive, kSuite for family        |
| Healthchecks.io | <https://healthchecks.io>        | [healthchecks-io.md](./services/healthchecks-io.md) | BorgBackup dead-man's switch            |
| UptimeRobot     | <https://uptimerobot.com>        | [uptimerobot.md](./services/uptimerobot.md)         | Public endpoint availability monitoring |

---

## Step 2 — Enable MFA on Accounts

**Where to store TOTP seeds and recovery codes:**

Haven uses a **two-vault strategy** — family credentials and admin credentials are deliberately kept separate:

| Audience       | Vault                                   | Purpose                                                                                                  |
| -------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Family members | **Vaultwarden** (self-hosted on Hearth) | Day-to-day passwords, TOTP codes, shared family items                                                    |
| Admin / system | **Bitwarden cloud** (bitwarden.com)     | Haven infrastructure accounts (INWX, GitHub, Hetzner, etc.) — break-the-glass fallback if Hearth is down |

**Why the split?** Not all eggs in one basket. If Hearth goes down, the admin can still access provider accounts via Bitwarden cloud to diagnose and recover — without touching the family vault.

**Bootstrap flow:**

1. Create **Bitwarden cloud** account first (free tier is sufficient)
2. Store all admin/system credentials and TOTP seeds there during setup
3. Once Vaultwarden is running, family members enroll there
4. Admin accounts stay in Bitwarden cloud permanently as the offsite break-the-glass copy

> **ACTION:** Enable MFA on every account above before proceeding. These accounts control your entire infrastructure. A compromised provider account can destroy everything.

| Account         | MFA method                   | Where to enable                                      | Notes                                                                                                               |
| --------------- | ---------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Bitwarden cloud | TOTP (authenticator app)     | Settings → Security → Two-step login                 | Store recovery code **offline** (printed paper or USB) — this is the one credential that cannot be stored in itself |
| INWX            | TOTP                         | Login → Security → 2FA                               | Controls DNS — hijacked registrar = traffic redirection                                                             |
| GitHub          | TOTP + passkey (recommended) | Settings → Password and authentication               | Protects IaC pipelines and GitHub Secrets (Hetzner API key, SSH keys)                                               |
| Hetzner Cloud   | TOTP                         | Account → Security → Two Factor Authentication       | Controls VPS provisioning, snapshots, and API tokens                                                                |
| Infisical Cloud | TOTP                         | User Settings → Security → Two-factor authentication | Controls runtime application secrets for all deployed services                                                      |
| Infomaniak      | TOTP                         | Profile → Security → Two-factor authentication       | Controls email, kDrive, and kSuite for all family members                                                           |
| Terraform Cloud | TOTP                         | User Settings → Security → Two-factor authentication | Controls remote state containing infrastructure metadata                                                            |

> **Authenticator app:** Use **Bitwarden Authenticator** (free, iOS + Android) for all TOTP codes.
>
> - **Family members:** Bitwarden Authenticator syncs TOTP seeds to Vaultwarden once deployed
> - **Admin:** Bitwarden Authenticator syncs TOTP seeds to Bitwarden cloud
> - Avoid SMS-based 2FA for all accounts
> - The Bitwarden cloud recovery code is the only credential that must be stored **offline** (printed paper or USB) — it cannot store itself

---

## Step 3 — Configure Accounts

> **ACTION:** Create accounts for each of these services, then store the credentials securely in Bitwarden. For each service, follow the linked guide for detailed setup instructions.

You will need accounts for the following services. Create them in the recommended order, since some credentials are needed for later steps.

| Service         | URL                              | Link                                    | Notes                                             |
| --------------- | -------------------------------- | --------------------------------------- | ------------------------------------------------- |
| Bitwarden       | <https://bitwarden.com>          | [click](../services/bitwarden.md)       | To store the break-the-glass credentials          |
| GitHub          | <https://github.com>             | [click](../services/github.md)          | To manage source code and CI/CD pipelines         |
| Infisical Cloud | <https://app.infisical.com>      | [click](../services/infisical.md)       | To manage runtime application secrets             |
| INWX            | <https://www.inwx.de>            | [click](../services/inwx.md)            | To manage DNS records                             |
| Hetzner         | <https://console.hetzner.cloud>  | [click](../services/hetzner.md)         | To provision and manage VPS instances and storage |
| Terraform Cloud | <https://app.terraform.io>       | [click](../services/terraform.md)       | To manage infrastructure state                    |
| Healthchecks.io | <https://healthchecks.io>        | [click](../services/healthchecks-io.md) | To monitor service uptime                         |
| UptimeRobot     | <https://uptimerobot.com>        | [click](../services/uptimerobot.md)     | To monitor service uptime                         |
| Infomaniak      | <https://manager.infomaniak.com> | [click](../services/infomaniak.md)      | To manage email and other services                |

> **Note** Secure storage of credentials is critical. Use Vaultwarden or another password manager to store all account credentials, API keys, and secrets. Avoid hardcoding sensitive information in code or configuration files. If needed store them temporarily in a secure notes section while setting up, then move to the password manager. From this point forward, we will assume all credentials are stored securely.

### Required Bitwarden Account

See [bitwarden.md](../services//bitwarden.md#bitwarden-setup) for detailed instructions on setting up your Bitwarden account and organizing your vault for the haven platform. In summary:

1. Create a Bitwarden account if you don't have one.
2. Create a new vault or folder named "Haven" to store all related credentials and secrets.

### Required GitHub Account

See [github.md](../services/github.md#initial-setup) for detailed instructions on setting up your GitHub account and repository for the haven platform. In summary:

1. Create a GitHub account if you don't have one.
2. Store the GitHub account credentials in Bitwarden.
3. Create a new repository named `haven` (or a name of your choice) to host the configuration and code for the haven platform.
4. Configure an Environment named `production` (or a name of your choice) in your repository.
5. Clone the repository to your local machine to start working with it.

### Required Infisical Cloud Account

See [infisical.md](../services/infisical.md#initial-setup) for detailed instructions on setting up your Infisical Cloud account and configuring application secrets for the haven platform. In summary:

1. Sign up at <https://app.infisical.com> using GitHub SSO.
2. Create an organization (e.g., `haven`)
3. Create a project (e.g., `haven`)

### Required INWX (Domain Registrar) Account

See [inwx.md](../services/inwx.md#initial-setup) for detailed instructions on setting up your INWX account and configuring DNS for the haven platform. In summary:

1. Sign up at <https://www.inwx.de/en>
2. Store the INWX account credentials in Bitwarden.

### Required Hetzner Cloud Account

See [hetzner.md](../services//hetzner.md#initial-setup) for detailed instructions on setting up your Hetzner Cloud account and provisioning infrastructure for the haven platform. In summary:

1. Sign up at <https://console.hetzner.cloud>
2. Store the Hetzner account credentials in Bitwarden.
3. Create a project named "Haven" to group all related resources (VMs, firewalls, storage boxes).

### Required Terraform Cloud Account

Strata's [Terraform](../terraform#initial-setup) provisioning uses Terraform Cloud as the remote state backend.

1. Sign up at <https://app.terraform.io/signup>
2. Create organization (e.g., `{org-name}`)
3. Generate API token: User Settings → Tokens → Create token
4. Store the API token in Bitwarden

> Note: Workspace will be created automatically by the workflow on first run, but you can pre-create it for convenience.

### Required Healthchecks.io Account

See [healthchecks-io.md](../services/healthchecks-io.md#initial-setup) for detailed instructions on setting up your Healthchecks.io account and configuring uptime monitoring for the haven platform. In summary:

1. Sign up at <https://healthchecks.io>
2. Store the Healthchecks.io account credentials in Bitwarden.

### Required UptimeRobot Account

See [uptimerobot.md](../services/uptimerobot.md#initial-setup) for detailed instructions on setting up your UptimeRobot account and configuring uptime monitoring for the haven platform. In summary:

1. Sign up at <https://uptimerobot.com>
2. Store the UptimeRobot account credentials in Bitwarden.

### Required Infomaniak Account

See [infomaniak.md](./services//infomaniak.md#initial-setup) for detailed instructions on setting up your Infomaniak account and configuring email and file services for the haven platform. In summary:

1. Sign up at <https://manager.infomaniak.com/en> for a **kSuite plan** with Mail, Files, and Drive services.
2. Store the Infomaniak account credentials in Bitwarden.

### Required Tool Installations

You will need the following tools installed on your workstation to follow this guide and manage the haven platform:

| Tool       | Version | Install                                                                              |
| ---------- | ------- | ------------------------------------------------------------------------------------ |
| `strata`   | ≥ 1.0.0 | `pip install xyz-strata==1.0.0`                                                      |
| OpenTofu   | ≥ 1.6   | `choco install opentofu` or [opentofu.org](https://opentofu.org/docs/intro/install/) |
| Ansible    | ≥ 2.14  | `pip install ansible-core`                                                           |
| GitHub CLI | latest  | `winget install GitHub.cli`                                                          |
| Git        | latest  | `winget install Git.Git`                                                             |

**Verify:**

```powershell
strata --version
tofu --version
ansible --version
gh --version
```

---

## Step 4 — Install Required Tools

Install on your local workstation before running any deployment commands.

| Tool       | Version | Install                                                                              |
| ---------- | ------- | ------------------------------------------------------------------------------------ |
| `strata`   | ≥ 1.0.0 | `pip install xyz-strata`                                                             |
| OpenTofu   | ≥ 1.6   | `choco install opentofu` or [opentofu.org](https://opentofu.org/docs/intro/install/) |
| Ansible    | ≥ 2.14  | `pip install ansible-core`                                                           |
| GitHub CLI | latest  | `winget install GitHub.cli`                                                          |
| Git        | latest  | `winget install Git.Git`                                                             |

**Verify:**

```powershell
strata --version
tofu --version
ansible --version
gh --version
git --version
```

---

## Checklist

- [ ] Bitwarden cloud account created + MFA enabled + recovery code stored offline
- [ ] All provider accounts created and MFA enabled
- [ ] Credentials stored in Bitwarden cloud
- [ ] Infisical Cloud organization + project created
- [ ] Terraform Cloud organization created + API token generated
- [ ] Domains registered/transferred at INWX
- [ ] GitHub repo created with `production` environment
- [ ] Hetzner project created + API token generated
- [ ] Infomaniak kSuite purchased + domains verified
- [ ] Healthchecks.io account created + check configured
- [ ] UptimeRobot account created
- [ ] All tools installed and verified
