# =============================================================================
# Kamatera VMs Module — Main
# Creates VMs, private network, TLS keys, and provisions with SSH
# =============================================================================

terraform {
  required_providers {
    kamatera = {
      source = "kamatera/kamatera"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# =============================================================================
# Locals
# =============================================================================

locals {
  # Region mapping: platform region code → Kamatera datacenter values
  region_map = {
    "eu-fr" = { country = "Germany", region = "Frankfurt" }
    "eu-nl" = { country = "Netherlands", region = "Amsterdam" }
    "us-ny" = { country = "United States", region = "New York" }
    "us-tx" = { country = "United States", region = "Dallas" }
    "il-ta" = { country = "Israel", region = "Rosh Haayin" }
  }

  datacenter = local.region_map[var.region]

  # Manager instances (for swarm init)
  managers = { for k, v in var.vm_instances : k => v if v.role == "manager" }
  workers  = { for k, v in var.vm_instances : k => v if v.role == "worker" }

  # Build per-instance configuration by looking up the resource definition
  vm_configs = {
    for key, instance in var.vm_instances : key => {
      name          = "${var.workspace_name}-${instance.role}-${instance.index}"
      role          = instance.role
      index         = instance.index
      resource_name = instance.resource
      config        = var.vm_resources[instance.resource].configuration
      storage       = var.vm_resources[instance.resource].storage
      firewall_key  = var.vm_resources[instance.resource].firewall
    }
  }
}

# =============================================================================
# Data Sources
# =============================================================================

data "kamatera_datacenter" "dc" {
  country = local.datacenter.country
  name    = local.datacenter.region
}

data "kamatera_image" "os" {
  for_each = { for k, v in local.vm_configs : k => v.config.os_code }

  datacenter_id = data.kamatera_datacenter.dc.id
  os            = each.value
}

# =============================================================================
# Random suffix for unique naming
# =============================================================================

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# =============================================================================
# Private Network (VLAN)
# =============================================================================

resource "kamatera_network" "private" {
  name          = "${var.workspace_name}-${random_string.suffix.result}"
  datacenter_id = data.kamatera_datacenter.dc.id
}

# =============================================================================
# Kamatera Servers
# =============================================================================

resource "kamatera_server" "vm" {
  for_each = local.vm_configs

  name          = each.value.name
  datacenter_id = data.kamatera_datacenter.dc.id
  image_id      = data.kamatera_image.os[each.key].id

  cpu_type      = each.value.config.cpu_type
  cpu_cores     = each.value.config.cpu_cores
  ram_mb        = each.value.config.ram_mb
  billing_cycle = each.value.config.billing

  # Primary disk from configuration
  disk_sizes_gb = concat(
    [each.value.config.disk_size != null ? each.value.config.disk_size : each.value.storage.disks[0].size],
    [for d in slice(each.value.storage.disks, 1, length(each.value.storage.disks)) : d.size]
  )

  # WAN interface (public IP)
  network {
    name = "wan"
  }

  # Private network interface
  network {
    name = kamatera_network.private.full_name
  }

  # SSH key for access
  ssh_pubkey = var.kamatera_public_key

  password = var.kamatera_root_password

  lifecycle {
    ignore_changes = [password]
  }
}

# =============================================================================
# SSH Provisioning — Base setup (all VMs)
# =============================================================================

resource "terraform_data" "provision_base" {
  for_each = local.vm_configs

  triggers_replace = [
    kamatera_server.vm[each.key].id
  ]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = kamatera_server.vm[each.key].public_ips[0]
      user        = "root"
      private_key = var.kamatera_private_key
    }

    inline = [
      "#!/bin/bash",
      "set -euo pipefail",
      "",
      "# Wait for cloud-init",
      "cloud-init status --wait || true",
      "",
      "# System update",
      "apt-get update -qq",
      "apt-get upgrade -y -qq",
      "",
      "# Install base packages",
      "apt-get install -y -qq curl wget apt-transport-https ca-certificates gnupg lsb-release ufw",
      "",
      "# Configure UFW firewall",
      "ufw --force reset",
      "ufw default deny incoming",
      "ufw default allow outgoing",
      "ufw allow 22/tcp comment 'SSH'",
    ]
  }
}

# =============================================================================
# SSH Provisioning — Firewall rules (UFW)
# =============================================================================

resource "terraform_data" "provision_firewall" {
  for_each = {
    for key, cfg in local.vm_configs : key => cfg
    if cfg.firewall_key != null && contains(keys(var.firewalls), cfg.firewall_key)
  }

  triggers_replace = [
    kamatera_server.vm[each.key].id
  ]

  depends_on = [terraform_data.provision_base]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = kamatera_server.vm[each.key].public_ips[0]
      user        = "root"
      private_key = var.kamatera_private_key
    }

    inline = concat(
      ["#!/bin/bash", "set -euo pipefail", ""],
      # Apply allow rules
      [
        for rule in var.firewalls[each.value.firewall_key].rules.allow :
        "ufw allow ${rule.port}/${rule.proto} comment '${rule.comment}'"
      ],
      # Apply deny rules
      [
        for rule in var.firewalls[each.value.firewall_key].rules.deny :
        "ufw deny ${rule.port}/${rule.proto} comment '${rule.comment}'"
      ],
      # Enable UFW
      ["ufw --force enable"]
    )
  }
}

# =============================================================================
# SSH Provisioning — Docker + Swarm
# =============================================================================

resource "terraform_data" "provision_docker" {
  for_each = local.vm_configs

  triggers_replace = [
    kamatera_server.vm[each.key].id
  ]

  depends_on = [terraform_data.provision_firewall]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = kamatera_server.vm[each.key].public_ips[0]
      user        = "root"
      private_key = var.kamatera_private_key
    }

    inline = [
      "#!/bin/bash",
      "set -euo pipefail",
      "",
      "# Install Docker",
      "curl -fsSL https://get.docker.com | sh",
      "",
      "# Enable Docker service",
      "systemctl enable docker",
      "systemctl start docker",
    ]
  }
}

# =============================================================================
# SSH Provisioning — Swarm Init (managers only)
# =============================================================================

resource "terraform_data" "swarm_init" {
  for_each = local.managers

  triggers_replace = [
    kamatera_server.vm[each.key].id
  ]

  depends_on = [terraform_data.provision_docker]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = kamatera_server.vm[each.key].public_ips[0]
      user        = "root"
      private_key = var.kamatera_private_key
    }

    inline = [
      "#!/bin/bash",
      "set -euo pipefail",
      "",
      "# Initialize Docker Swarm on the private network IP",
      "PRIVATE_IP=$(ip -4 addr show eth1 | grep -oP '(?<=inet\\s)\\d+\\.\\d+\\.\\d+\\.\\d+')",
      "docker swarm init --advertise-addr $PRIVATE_IP || true",
      "",
      "# Store join token for workers",
      "docker swarm join-token worker -q > /tmp/swarm-worker-token",
    ]
  }
}

# =============================================================================
# SSH Provisioning — Swarm Join (workers only)
# =============================================================================

resource "terraform_data" "swarm_join" {
  for_each = local.workers

  triggers_replace = [
    kamatera_server.vm[each.key].id
  ]

  depends_on = [terraform_data.swarm_init]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = kamatera_server.vm[each.key].public_ips[0]
      user        = "root"
      private_key = var.kamatera_private_key
    }

    inline = [
      "#!/bin/bash",
      "set -euo pipefail",
      "",
      "# Get the manager IP and join token",
      "MANAGER_IP=${kamatera_server.vm[keys(local.managers)[0]].private_ips[0]}",
      "WORKER_TOKEN=$(ssh -o StrictHostKeyChecking=no -i /tmp/key root@$MANAGER_IP cat /tmp/swarm-worker-token)",
      "",
      "# Join the swarm",
      "docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377 || true",
    ]
  }
}

# =============================================================================
# SSH Provisioning — Storage setup
# =============================================================================

resource "terraform_data" "provision_storage" {
  for_each = {
    for key, cfg in local.vm_configs : key => cfg
    if cfg.storage != null
  }

  triggers_replace = [
    kamatera_server.vm[each.key].id
  ]

  depends_on = [terraform_data.provision_docker]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = kamatera_server.vm[each.key].public_ips[0]
      user        = "root"
      private_key = var.kamatera_private_key
    }

    inline = concat(
      ["#!/bin/bash", "set -euo pipefail", ""],
      # Create install path
      ["mkdir -p ${each.value.storage.install_path}"],
      # Create disk mount points
      [
        for disk in each.value.storage.disks :
        "mkdir -p ${disk.mount}"
      ],
      # Create volume directories
      [
        for vol in each.value.storage.volumes :
        "mkdir -p ${vol.path}"
      ]
    )
  }
}
