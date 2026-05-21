# =============================================================================
# Outputs
# =============================================================================

output "platform" {
  description = "Platform deployment summary"
  value = {
    workspace   = var.workspace_name
    environment = var.environment
    version     = var.workspace_version
  }
}

# output "virtual_machines" {
#   description = "Provisioned VM instances with network details"
#   value       = module.kamatera_vms.instances
# }

# output "private_network" {
#   description = "Private network CIDR"
#   value       = module.kamatera_vms.private_network
# }
