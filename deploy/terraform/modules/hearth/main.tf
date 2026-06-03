# =============================================================================
# Module: Hearth — Hetzner Cloud Resources
# =============================================================================
# Provisions the Hearth VPS: CX22 running Docker Compose stack
# (Caddy, Authentik, Vaultwarden, Infisical)
#
# Firewall rules are built dynamically from the strata firewalls config.
# Loopback/interface rules are filtered out — those are OS-level (nftables).
# =============================================================================

# =============================================================================
# Locals — filter firewall rules to hcloud-compatible ones
# =============================================================================

locals {
  # hcloud firewalls only support network rules, not interface rules (lo)
  # Filter to rules that have proto + port (skip interface-only rules)
  network_rules = [
    for rule in var.firewall_config.rules.allow : rule
    if rule.proto != null && rule.interface == null
  ]

  inbound_rules = [
    for rule in local.network_rules : rule
    if rule.direction == "in"
  ]

  outbound_rules = [
    for rule in local.network_rules : rule
    if rule.direction == "out"
  ]
}

# =============================================================================
# Firewall
# =============================================================================

resource "hcloud_firewall" "hearth" {
  name   = "${var.workspace_name}-fw-hearth"
  labels = merge(var.labels, { role = "hearth" })

  # Inbound rules
  dynamic "rule" {
    for_each = local.inbound_rules
    content {
      description = rule.value.comment
      direction   = "in"
      protocol    = rule.value.proto
      port        = rule.value.port != null ? (length(rule.value.port) == 1 ? tostring(rule.value.port[0]) : "${rule.value.port[0]}-${rule.value.port[length(rule.value.port) - 1]}") : null
      source_ips  = rule.value.from != null ? [rule.value.from] : ["0.0.0.0/0", "::/0"]
    }
  }

  # Outbound rules
  dynamic "rule" {
    for_each = local.outbound_rules
    content {
      description     = rule.value.comment
      direction       = "out"
      protocol        = rule.value.proto
      port            = rule.value.port != null ? (length(rule.value.port) == 1 ? tostring(rule.value.port[0]) : "${rule.value.port[0]}-${rule.value.port[length(rule.value.port) - 1]}") : null
      destination_ips = ["0.0.0.0/0", "::/0"]
    }
  }
}

# =============================================================================
# Server
# =============================================================================
# CX22: 2 vCPU, 4 GB RAM, 40 GB SSD
# Volumes at /opt/haven/ are directories on root disk, not block volumes.
# lifecycle.prevent_destroy — this is production, accidental destroy is catastrophic.

resource "hcloud_server" "hearth" {
  name        = "${var.workspace_name}-hearth"
  server_type = var.resource_config.configuration.server_type
  image       = var.resource_config.configuration.image
  location    = var.resource_config.configuration.location
  ssh_keys    = [var.ssh_key_id]
  labels      = merge(var.labels, { role = "hearth" })

  firewall_ids = [hcloud_firewall.hearth.id]

  user_data = <<-EOF
    #cloud-config
    runcmd:
      - mkdir -p ${var.resource_config.storage.install_path}/{etc,var/data,var/logs,var/certs}
  EOF

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Network Attachment
# =============================================================================

resource "hcloud_server_network" "hearth" {
  server_id  = hcloud_server.hearth.id
  network_id = var.network_id
}
