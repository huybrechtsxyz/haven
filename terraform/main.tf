# =============================================================================
# Haven Platform — Terraform Root Module
# Consumes *.auto.tfvars.json from the platform build output
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    kamatera = {
      source = "kamatera/kamatera"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  cloud {
    organization = "huybrechts"
    workspaces {
      name = "haven-platform"
    }
  }
}

# =============================================================================
# Locals — flatten topology components into individual VM instances
# =============================================================================

locals {
  # Flatten all topology components into VM instances using their count
  # Result: list of { key, resource, role, index, config }
  vm_instances = flatten([
    for topo_name, topo in var.topologies : [
      for comp in topo.components : [
        for i in range(comp.count) : {
          key      = "${comp.resource}-${i + 1}"
          resource = comp.resource
          role     = comp.role
          index    = i + 1
          provider = topo.provider
        }
      ]
    ]
  ])

  # Convert to map for for_each
  vm_instance_map = { for vm in local.vm_instances : vm.key => vm }

  # Find the first Kamatera provider (for region lookup)
  kamatera_provider = [
    for name, p in var.platform_providers : p
    if p.type == "kamatera"
  ][0]
}

# =============================================================================
# Kamatera VMs Module
# =============================================================================

# module "kamatera_vms" {
#   source = "./modules/kamatera_vms"

#   workspace_name = var.workspace_name
#   environment    = var.environment
#   region         = local.kamatera_provider.region

#   vm_instances = local.vm_instance_map
#   vm_resources = var.resources
#   firewalls    = var.firewalls

#   kamatera_api_key       = var.KAMATERA_API_KEY
#   kamatera_api_secret    = var.KAMATERA_API_SECRET
#   kamatera_root_password = var.KAMATERA_ROOT_PASSWORD
#   kamatera_private_key   = var.KAMATERA_PRIVATE_KEY
#   kamatera_public_key    = var.KAMATERA_PUBLIC_KEY
# }
