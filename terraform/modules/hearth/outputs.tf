# =============================================================================
# Module: Hearth — Outputs
# =============================================================================

output "public_ip" {
  description = "Hearth public IPv4 — use for DNS A records"
  value       = hcloud_server.hearth.ipv4_address
}

output "public_ipv6" {
  description = "Hearth public IPv6"
  value       = hcloud_server.hearth.ipv6_address
}

output "private_ip" {
  description = "Hearth private IP on haven network"
  value       = hcloud_server_network.hearth.ip
}

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.hearth.id
}

output "firewall_id" {
  description = "Hearth firewall ID"
  value       = hcloud_firewall.hearth.id
}
