# =============================================================================
# Haven Platform — Root Module
# =============================================================================
# Shared infrastructure (network, SSH key) + one module per node.
# Inputs come from locals only (strata.tf maps the strata payload onto them).
#
# Hearth: Docker Compose — Caddy, Authentik, Vaultwarden, Portainer, WUD
# Forge:  k3s — Immich, Jellyfin, Nextcloud, Gatus, apps
#
# Resource addresses and name strings must stay as they are: they match the
# live Terraform Cloud state (haven_deploy_prd) and the real Hetzner objects.
# =============================================================================

# =============================================================================
# Locals
# =============================================================================

locals {
  # Hetzner resource names must be valid RFC 1123 hostnames (no underscores).
  # The workspace name uses underscores ("haven_platform") — replace with hyphens.
  safe_name = replace(local.workspace_name, "_", "-")

  common_labels = {
    workspace   = local.workspace_name
    environment = local.environment
    version     = local.workspace_ver
    managed_by  = "opentofu"
  }
}

# =============================================================================
# SSH Key (shared across all nodes)
# =============================================================================

resource "hcloud_ssh_key" "haven" {
  name       = "${local.safe_name}-deploy"
  public_key = local.ssh_public_key
  labels     = local.common_labels
}

# =============================================================================
# Private Network (shared — Hearth <-> Forge communication)
# =============================================================================

resource "hcloud_network" "haven" {
  name     = "${local.safe_name}-net"
  ip_range = var.network_cidr
  labels   = local.common_labels
}

resource "hcloud_network_subnet" "haven" {
  network_id   = hcloud_network.haven.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_cidr
}

# =============================================================================
# Module — Hearth
# =============================================================================

module "hearth" {
  source = "./modules/hearth"

  depends_on = [hcloud_network_subnet.haven]

  name_prefix    = local.safe_name
  server_type    = local.vms["hearth"].server_type
  image          = local.vms["hearth"].image
  location       = local.vms["hearth"].location
  install_path   = local.vms["hearth"].install_path
  firewall_rules = local.vms["hearth"].firewall_rules
  ssh_key_id     = hcloud_ssh_key.haven.id
  network_id     = hcloud_network.haven.id
  labels         = local.common_labels
}

# =============================================================================
# Module — Forge
# =============================================================================

module "forge" {
  source = "./modules/forge"

  depends_on = [hcloud_network_subnet.haven]

  name_prefix    = local.safe_name
  server_type    = local.vms["forge"].server_type
  image          = local.vms["forge"].image
  location       = local.vms["forge"].location
  install_path   = local.vms["forge"].install_path
  firewall_rules = local.vms["forge"].firewall_rules
  ssh_key_id     = hcloud_ssh_key.haven.id
  network_id     = hcloud_network.haven.id
  labels         = local.common_labels
}
