# Terraform Cloud

Terraform Cloud is a hosted service by HashiCorp that provides a collaborative environment for managing Terraform configurations and state. It offers features like remote state management, version control integration, and team collaboration tools. In the haven platform, we use Terraform Cloud to manage our infrastructure as code, allowing us to provision and maintain our servers and services in a consistent and automated way.

## Initial Setup

**Account setup** — To use Terraform Cloud, you need to create an account and set up an organization. This organization will serve as a container for your workspaces, which are used to manage different environments or projects.

1. Sign up for a Terraform Cloud account at <https://app.terraform.io/signup>.
2. Enable MFA immediately after account creation:
   - Go to User Settings -> Security -> Two-factor authentication
   - Scan QR code with **Bitwarden Authenticator**
   - Store the TOTP seed and recovery code in **Bitwarden cloud** (not Vaultwarden)

**Organization and workspace setup** — After creating your account, you need to set up an organization and a workspace. The organization groups your workspaces, while the workspace is where your Terraform configurations and state are managed.

3. Create an organization (e.g., `{org-name}`) to group your workspaces.
4. Generate an API token by going to User Settings → Tokens → Create token. This token will be used by the GitHub Actions workflow to authenticate with Terraform Cloud and manage the infrastructure.
5. Store the API token and account credentials in **Bitwarden cloud**, linked to your Terraform Cloud account entry.

> Note: Workspace will be created automatically by the workflow on first run, but you can pre-create it for convenience.
