# =============================================================================
# Module: Forge — Hetzner Cloud Resources
# =============================================================================
# Wave 2: CPX41 running k3s single-node (Immich, Gatus, apps)
#
# Forge only accepts traffic from Hearth (private network) for HTTP/HTTPS.
# k3s API is private-network only. No public ingress.
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
  name   = "${var.workspace_name}-fw-forge"
  labels = merge(var.labels, { role = "forge" })

  dynamic "rule" {
    for_each = local.inbound_rules
    content {
      description = rule.value.comment
      direction   = "in"
      protocol    = rule.value.proto
      port        = rule.value.port != null ? (can(tolist(rule.value.port)) ? "${tolist(rule.value.port)[0]}-${tolist(rule.value.port)[length(tolist(rule.value.port)) - 1]}" : tostring(rule.value.port)) : null
      source_ips  = rule.value.from != null ? [rule.value.from] : ["0.0.0.0/0", "::/0"]
    }
  }

  dynamic "rule" {
    for_each = local.outbound_rules
    content {
      description     = rule.value.comment
      direction       = "out"
      protocol        = rule.value.proto
      port            = rule.value.port != null ? (can(tolist(rule.value.port)) ? "${tolist(rule.value.port)[0]}-${tolist(rule.value.port)[length(tolist(rule.value.port)) - 1]}" : tostring(rule.value.port)) : null
      destination_ips = ["0.0.0.0/0", "::/0"]
    }
  }
}

# =============================================================================
# Server
# =============================================================================
# CPX41: 4 vCPU, 8 GB RAM, 160 GB SSD
# k3s workloads: Immich (photo library), Gatus (monitoring), future apps

resource "hcloud_server" "forge" {
  name        = "${var.workspace_name}-forge"
  server_type = var.resource_config.configuration.server_type
  image       = var.resource_config.configuration.image
  location    = var.resource_config.configuration.location
  ssh_keys    = [var.ssh_key_id]
  labels      = merge(var.labels, { role = "forge" })

  firewall_ids = [hcloud_firewall.forge.id]

  user_data = <<-EOF
    #cloud-config
    runcmd:
      - mkdir -p ${var.resource_config.storage.install_path}/{data,k3s,logs}
  EOF

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# Network Attachment
# =============================================================================

resource "hcloud_server_network" "forge" {
  server_id  = hcloud_server.forge.id
  network_id = var.network_id

  depends_on = [var.subnet_id]
}
