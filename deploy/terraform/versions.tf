# =============================================================================
# Haven Platform — Terraform/OpenTofu Version & Provider Requirements
# =============================================================================
# Hetzner Cloud provider for VPS, networking, and firewall provisioning.
# State stored in Terraform Cloud (remote backend).
# Auth: set TF_TOKEN_app_terraform_io env var or run `terraform login`.
# =============================================================================

terraform {
  required_version = ">= 1.6" # OpenTofu 1.6+

  cloud {
    organization = "huybrechts-xyz"
    workspaces {
      name = "haven_deploy_prd"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "hcloud" {
  token = var.HETZNER_API_TOKEN
}
