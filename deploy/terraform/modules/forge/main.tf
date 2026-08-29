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
      destination_ips = rule.value.to != null ? [rule.value.to] : ["0.0.0.0/0", "::/0"]
    }
  }
}

# =============================================================================
# Server
# =============================================================================
# CPX41: 8 vCPU, 16 GB RAM, 240 GB SSD
# k3s is installed via Ansible after provisioning.
# lifecycle.prevent_destroy  — production node; accidental destroy would lose k3s state.
# lifecycle.ignore_changes   — server_type ignored after creation (resize without destroy).
#   user_data is ALSO ignored — the hcloud provider treats user_data as a
#   force-replacement attribute (cloud-init only runs on first boot, so
#   Terraform can't apply a changed value in place). Editing the mkdir list
#   below is safe for documentation/new-server bootstrap purposes, but has NO
#   effect on an already-provisioned server — ongoing directory management for
#   a live server is Ansible's job (forge-init.yml/forge-config.yml), which is
#   idempotent and re-runnable. Without this ignore, ANY edit to user_data
#   plans to destroy+recreate this production node (caught once already by
#   prevent_destroy — 2026-08-29).

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
      - mkdir -p /mnt/haven-data-media
      - mkdir -p /mnt/haven-data-docs
  EOF

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [server_type, user_data]
  }
}

# =============================================================================
# Network Attachment
# =============================================================================

resource "hcloud_server_network" "forge" {
  server_id  = hcloud_server.forge.id
  network_id = var.network_id
}
