# =============================================================================
# Module: Hearth — Hetzner Cloud Resources
# =============================================================================
# Provisions the Hearth VPS: CX23 running the Docker Compose stack
# (Caddy, Authentik, Vaultwarden, Portainer, WUD).
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

resource "hcloud_firewall" "hearth" {
  name   = "${var.name_prefix}-fw-hearth"
  labels = merge(var.labels, { role = "hearth" })

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
# CX23: 2 vCPU, 4 GB RAM, 40 GB SSD
# Volumes at /opt/haven/ are directories on root disk, not block volumes.
# lifecycle.prevent_destroy  — this is production, accidental destroy is catastrophic.
# lifecycle.ignore_changes   — server_type is ignored after creation.
#   Hetzner periodically renames server type identifiers (e.g. cx22 → cx23 in 2025).
#   Existing servers keep running under the old name but the API rejects it on new creates.
#   Without this ignore, Terraform sees a perpetual drift between the declared name and
#   what the API reports, and attempts an unwanted resize/reboot on every apply.
#   To intentionally resize: update server_type in config/hearth/vm.yaml, temporarily
#   remove ignore_changes, apply once, then restore it.
#   user_data is ALSO ignored — the hcloud provider treats user_data as a
#   force-replacement attribute (cloud-init only runs on first boot). Editing
#   the mkdir list is safe for documentation/new-server bootstrap purposes
#   only — it has no effect on an already-provisioned server (Ansible owns
#   ongoing directory management there). Without this ignore, any user_data
#   edit plans to destroy+recreate this production node.

resource "hcloud_server" "hearth" {
  name        = "${var.name_prefix}-hearth"
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [var.ssh_key_id]
  labels      = merge(var.labels, { role = "hearth" })

  firewall_ids = [hcloud_firewall.hearth.id]

  user_data = <<-EOF
    #cloud-config
    runcmd:
      - mkdir -p ${var.install_path}/{etc,var/data,var/logs,var/certs}
  EOF

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [server_type, user_data]
  }
}

# =============================================================================
# Network Attachment
# =============================================================================

resource "hcloud_server_network" "hearth" {
  server_id  = hcloud_server.hearth.id
  network_id = var.network_id
}
