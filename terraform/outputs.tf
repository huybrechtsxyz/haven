# =============================================================================
# Root Outputs
# =============================================================================

output "platform" {
  description = "Platform deployment summary"
  value = {
    workspace   = var.workspace_name
    environment = var.environment
    version     = var.workspace_version
  }
}

# --- Hearth ---

output "hearth_public_ip" {
  description = "Hearth public IPv4 — DNS A records point here"
  value       = module.hearth.public_ip
}

output "hearth_public_ipv6" {
  description = "Hearth public IPv6"
  value       = module.hearth.public_ipv6
}

output "hearth_private_ip" {
  description = "Hearth private IP on haven network"
  value       = module.hearth.private_ip
}

output "hearth_server_id" {
  description = "Hearth Hetzner server ID"
  value       = module.hearth.server_id
}

# --- Forge (Wave 2) ---

# output "forge_public_ip" {
#   description = "Forge public IPv4"
#   value       = module.forge.public_ip
# }

# output "forge_private_ip" {
#   description = "Forge private IP on haven network"
#   value       = module.forge.private_ip
# }

# output "forge_server_id" {
#   description = "Forge Hetzner server ID"
#   value       = module.forge.server_id
# }

# --- Network ---

output "network_id" {
  description = "Haven private network ID"
  value       = hcloud_network.haven.id
}

output "network_cidr" {
  description = "Haven private network CIDR"
  value       = hcloud_network.haven.ip_range
}
