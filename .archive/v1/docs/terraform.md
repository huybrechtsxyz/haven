# Terraform Cloud

Terraform Cloud is a hosted service by HashiCorp that provides a collaborative environment for managing Terraform configurations and state. It offers features like remote state management, version control integration, and team collaboration tools. In the haven platform, we use Terraform Cloud to manage our infrastructure as code, allowing us to provision and maintain our servers and services in a consistent and automated way.

## Initial Setup

1. Sign up for a Terraform Cloud account at <https://app.terraform.io/signup>.
2. Create an organization (e.g., `{org-name}`) to group your workspaces.
3. Generate an API token by going to User Settings → Tokens → Create token. This token will be used by the GitHub Actions workflow to authenticate with Terraform Cloud and manage the infrastructure.
4. Store the API token securely in Bitwarden, linked to your Terraform Cloud account entry.

> Note: Workspace will be created automatically by the workflow on first run, but you can pre-create it for convenience.
