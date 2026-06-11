# =============================================================================
# Module: Forge — Hetzner Cloud Resources
# =============================================================================
# Provisions the Forge VPS: CPX41 running k3s single-node cluster
# (Immich, Jellyfin, Gatus, home-grown apps via Helm + Argo CD)
#
# Firewall rules are built dynamically from the strata firewalls config.
# Loopback/interface rules are filtered out — those are OS-level (nftables).
# =============================================================================

# =============================================================================
# Locals — filter firewall rules to hcloud-compatible ones
# =============================================================================

locals {
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

resource "hcloud_firewall" "forge" {
  name   = "${replace(var.workspace_name, "_", "-")}-fw-forge"
  labels = merge(var.labels, { role = "forge" })

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
# CPX41: 8 vCPU, 16 GB RAM, 240 GB SSD
# k3s is installed via Ansible after provisioning.
# lifecycle.prevent_destroy  — production node; accidental destroy would lose k3s state.
# lifecycle.ignore_changes   — server_type ignored after creation (see hearth module note).

resource "hcloud_server" "forge" {
  name        = "${replace(var.workspace_name, "_", "-")}-forge"
  server_type = var.resource_config.configuration.server_type
  image       = var.resource_config.configuration.image
  location    = var.resource_config.configuration.location
  ssh_keys    = [var.ssh_key_id]
  labels      = merge(var.labels, { role = "forge" })

  firewall_ids = [hcloud_firewall.forge.id]

  user_data = <<-EOF
    #cloud-config
    runcmd:
      - mkdir -p ${var.resource_config.storage.install_path}/{var/data,var/logs}
      - mkdir -p /mnt/storagebox
  EOF

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [server_type]
  }
}

# =============================================================================
# Network Attachment
# =============================================================================

resource "hcloud_server_network" "forge" {
  server_id  = hcloud_server.forge.id
  network_id = var.network_id
}
