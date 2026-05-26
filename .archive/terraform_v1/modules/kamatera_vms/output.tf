# =============================================================================
# Kamatera VMs Module — Outputs
# =============================================================================

output "instances" {
  description = "Provisioned VM instances with network details"
  value = {
    for key, cfg in local.vm_configs : key => {
      name       = cfg.name
      role       = cfg.role
      index      = cfg.index
      resource   = cfg.resource_name
      public_ip  = kamatera_server.vm[key].public_ips[0]
      private_ip = kamatera_server.vm[key].private_ips[0]
    }
  }
}

output "private_network" {
  description = "Private network CIDR"
  value       = kamatera_network.private.id
}

output "manager_ip" {
  description = "Manager node public IP"
  value = length(local.managers) > 0 ? (
    kamatera_server.vm[keys(local.managers)[0]].public_ips[0]
  ) : null
}
