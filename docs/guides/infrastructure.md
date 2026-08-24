# Haven Infrastructure

> This document describes the infrastructure provisioning and configuration for a Haven deployment.

[← Back to Guide](./index.md)

## Infrastructure Setup

Hetzner Cloud is the VPS hosting provider for haven. You will need to create a project, generate an API token, and add the SSH public key for deployment. Should have been done in the [previous](prerequisites.md) phase.

### Infrastructure Storage Box

The Hetzner Storage Box (sub-accounts, passwords, hostnames) should already be set up and stored in Bitwarden/Infisical Cloud.  
See [Secrets for Hetzner Storagebox](./setup.md#secrets-for-hetzner-storagebox).  
See [Hetzner Setup](../services/hetzner.md#create-a-hetzner-cloud-storagebox) if you still need to create it.

### Infrastructure S3 Object Storage

The S3 access key pair should already be generated and stored as part of [Secrets for Hetzner S3 Storage](./setup.md#secrets-for-hetzner-s3-storage). See [Hetzner Setup](../services/hetzner.md#create-hetzner-cloud-s3-access-keys) if you still need to create it.

The buckets themselves are provisioned automatically by the `deploy-infra.yml` workflow (`run_s3: true`), using the `deploy/ansible-s3/forge-s3.yml` playbook:

| Bucket          | Purpose                               |
| --------------- | ------------------------------------- |
| `haven-photos`  | Immich external photo library         |
| `haven-media`   | Media overflow (large binary assets)  |
| `haven-archive` | Cold storage, documents, exports      |
| `haven-docs`    | Documentation and operational exports |

This is idempotent and safe to re-run.

### Infrastructure Connectivity

The Hetzner Cloud project, SSH deployment key, and API token should already be set up and stored in Bitwarden/Infisical Cloud as part of [Secrets for Hetzner API Token](./setup.md#secrets-for-hetzner-api-token) and [Secrets for Hetzner SSH Deployment Key](./setup.md#secrets-for-hetzner-ssh-deployment-key). See [Hetzner Setup](../services/hetzner.md#initial-setup) if you still need to create the project, API token, or SSH key.

> The SSH public key is registered at **project level** — Terraform injects it into every VPS it creates (Hearth, Forge, any future nodes). One key pair covers all servers.

The VPS provisioning and configuration is handled by the `deploy-infra.yml` GitHub Actions workflow — there's no need to manually create or configure VPS instances at this stage. The workflow provisions the VPS, configures it with Ansible, and deploys the Docker Compose stack.

### Infrastructure Workflow

> **ACTION:** Run the infrastructure provisioning workflow
> **RESULT:** The VPS are provisioned, firewall rules are applied, and the network is configured.

The configuration for haven is defined in the `config/` directory using Strata's Kubernetes-style schema. Strata reads these YAML files and generates the Terraform artifacts consumed by the deployment workflow.

Infrastructure provisioning is handled by the `deploy-infra.yml` GitHub Actions workflow. This workflow uses the Hetzner API and the deployment SSH key to provision the VPS, apply Terraform changes, and configure S3 storage.

When we first run the deployment workflows, they will provision the infrastructure defined in the Strata configuration. This includes creating the VPS instance for the hearth system, setting up the firewall rules, and configuring the network settings.

GitHub Actions → Select `deploy-infra` → Run workflow. This runs `strata build` + Terraform to provision the VPS, firewall, and network. Use these inputs:

| Input     | Value           | Notes                                                                                                                   |
| --------- | --------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `branch`  | *your branch*   | Must match the branch the workflow is running on — **`main` is blocked**, use a feature branch                          |
| `dry_run` | `true`          | First run: preview the Terraform plan only, nothing is applied                                                          |
| `stage`   | *(leave empty)* | Empty = run all stages (`infrastructure_hearth`, `infrastructure_forge`). Set to one stage name to target just that VPS |
| `run_s3`  | `true`          | Provision S3 buckets — idempotent, safe to re-run                                                                       |

After reviewing the plan, run again with `dry_run: false` to apply.

> Note the **server IP** from the Terraform output — you need it for DNS A records at INWX.

**Why `dry_run` still matters even though Terraform is idempotent:** idempotency guarantees re-applying the *same* config twice produces the same result — it doesn't guarantee a change you just made is safe. Some Terraform changes force **resource replacement** (destroy + recreate) rather than an in-place update, e.g. renaming a server or changing an immutable attribute. `dry_run: true` runs a plan only, so replace/destroy actions are visible before they actually happen.

**Why `run_s3` stays an explicit opt-in even though it's idempotent:** idempotent means safe to re-run, not free to re-run — it's a separate Ansible playbook with its own API calls. Since `deploy-infra.yml` normally runs only once, rarely, after infrastructure changes (see [Deployment Workflow](./index.md#deployment-workflow)), leaving it off by default avoids an unnecessary pass when only Terraform changes (e.g. a firewall rule) are needed and the buckets already exist.

### Infrastructure DNS Records

> **ACTION:** Add DNS A records at INWX pointing to the Hearth server IP provisioned by Terraform.

Once you have the Hearth server IP from the Terraform output, every A record in the DNS table (root domain, `auth.`, `vault.`, `secrets.`, `portainer.`, `wud.`, `status.`) points to that same IP — Caddy on Hearth reverse-proxies all of them. See [domains.md](./domains.md#dns-records-for-base-domain) for the full DNS record list and [inwx.md](../services/inwx.md#nameserver-configuration) for INWX configuration.

> Forge isn't covered by this table yet — if/when Forge-hosted services (Immich, Jellyfin, Gatus) need their own public DNS entries rather than being proxied through Hearth, add them to `domains.md` at that point.
