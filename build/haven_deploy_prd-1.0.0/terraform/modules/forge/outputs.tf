# =============================================================================
# Module: Forge — Outputs
# =============================================================================

output "public_ip" {
  description = "Forge public IPv4"
  value       = hcloud_server.forge.ipv4_address
}

output "public_ipv6" {
  description = "Forge public IPv6"
  value       = hcloud_server.forge.ipv6_address
}

output "private_ip" {
  description = "Forge private IP on haven network"
  value       = hcloud_server_network.forge.ip
}

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.forge.id
}

output "firewall_id" {
  description = "Forge firewall ID"
  value       = hcloud_firewall.forge.id
}
