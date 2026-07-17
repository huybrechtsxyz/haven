# Hetzner Cloud

Hetzner Cloud is the hosting provider for the haven platform. The infrastructure is provisioned using OpenTofu and configured using Ansible, with deployment automation via GitHub Actions.

StorageBoxes are used for off-site backups with BorgBackup. The deployment workflow includes specific steps to manage Hetzner firewalls for secure SSH access during provisioning and restore operations.

## Initial Setup

1. Sign up for a Hetzner Cloud account at <https://console.hetzner.cloud>.
2. Store the Hetzner account credentials securely in Bitwarden.
3. Create a project named "Haven" to group all related resources (VMs, firewalls, storage boxes).
