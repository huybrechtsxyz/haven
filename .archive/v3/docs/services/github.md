# GitHub

GitHub is the source of truth for all configuration, deployment artifacts, and code related to the haven platform.

## Initial Setup

**Account creation and MFA** — GitHub is the source of truth for all configuration, deployment artifacts, and code related to the haven platform. It is critical that the account is secured with multi-factor authentication (MFA) and that the credentials are stored in a secure password manager (Bitwarden).

1. Create a GitHub account if you don't have one.
2. Enable MFA immediately after account creation:
   - Go to Settings → Password and authentication → Two-factor authentication
   - Scan QR code with **Bitwarden Authenticator**
   - Store the TOTP seed and recovery code in **Bitwarden cloud** (not Vaultwarden)
   - Optional but recommended: also add a **passkey** (Settings → Passkeys) for passwordless login
3. Store the GitHub account credentials in **Bitwarden cloud**.

**Repository setup** — The haven platform's configuration and code will be hosted in a GitHub repository. This repository will serve as the central point for collaboration, version control, and deployment automation.

1. Create a new repository named `haven` (or a name of your choice) to host the configuration and code for the haven platform.
2. Configure an Environment named `production` (or a name of your choice) in your repository.
3. Clone the repository to your local machine to start working with it.
4. Set up branch protection rules for the `main` branch to require pull request reviews before merging.
5. Create a `.github/workflows` directory in the repository to store GitHub Actions workflow files for CI/CD automation.
6. Create a `README.md` file and other Github documentation files with an overview of the haven platform, setup instructions, and links to relevant documentation.

**Standard file structure** — The repository should follow a standard file structure to organize configuration files, scripts, and documentation. This structure will help maintain clarity and ease of navigation for contributors.

```ps
{root}/
├── .github/
│   └── workflows/          # GitHub Actions workflow files
├── config/                 # Configuration files for services
├── docs/                   # Documentation files
├── scripts/                # Deployment and utility scripts
├── services/               # Service-specific configuration and scripts
└── README.md               # Overview and setup instructions
```
