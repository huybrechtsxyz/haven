# =============================================================================
# Module: Forge — Hetzner Cloud Resources
# =============================================================================
# Provisions the Forge VPS: CPX41 running a k3s single-node cluster
# (Immich, Jellyfin, Nextcloud, Gatus, apps via Helm).
# =============================================================================

locals {
  # Hetzner wants one port ("443") or a range ("20-21").
  rules = [
    for rule in var.firewall_rules : merge(rule, {
      port = length(rule.ports) == 0 ? null : (
        length(rule.ports) == 1 ? replace(rule.ports[0], ":", "-") : "${rule.ports[0]}-${rule.ports[length(rule.ports) - 1]}"
      )
    })
  ]
}

# =============================================================================
# Firewall
# =============================================================================

resource "hcloud_firewall" "forge" {
  name   = "${var.name_prefix}-fw-forge"
  labels = merge(var.labels, { role = "forge" })

  # Inbound rules
  dynamic "rule" {
    for_each = [for r in local.rules : r if r.direction == "in"]
    content {
      description = rule.value.description
      direction   = "in"
      protocol    = rule.value.protocol
      port        = rule.value.port
      source_ips  = rule.value.cidrs
    }
  }

  # Outbound rules
  dynamic "rule" {
    for_each = [for r in local.rules : r if r.direction == "out"]
    content {
      description     = rule.value.description
      direction       = "out"
      protocol        = rule.value.protocol
      port            = rule.value.port
      destination_ips = rule.value.cidrs
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
  name        = "${var.name_prefix}-forge"
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [var.ssh_key_id]
  labels      = merge(var.labels, { role = "forge" })

  firewall_ids = [hcloud_firewall.forge.id]

  user_data = <<-EOF
    #cloud-config
    runcmd:
      - mkdir -p ${var.install_path}/{var/data,var/logs}
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
