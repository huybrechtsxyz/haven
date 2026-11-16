# =============================================================================
# Module: Forge — Input Variables
# =============================================================================

variable "name_prefix" {
  description = "Prefix for Hetzner resource names (RFC 1123, e.g. haven-platform)"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type (e.g. cpx41) — ignored after creation, see main.tf"
  type        = string
}

variable "image" {
  description = "OS image slug (e.g. ubuntu-24.04)"
  type        = string
}

variable "location" {
  description = "Hetzner datacenter location (e.g. nbg1)"
  type        = string
}

variable "install_path" {
  description = "Base directory created by cloud-init on first boot (e.g. /opt/haven)"
  type        = string
}

variable "firewall_rules" {
  description = "Allow rules for the cloud firewall. ports: one entry (\"443\", \"80:90\") or a list whose first and last entry bound a range."
  type = list(object({
    direction   = string
    protocol    = string
    ports       = list(string)
    cidrs       = list(string)
    description = string
  }))
}

variable "ssh_key_id" {
  description = "Hetzner SSH key resource ID"
  type        = string
}

variable "network_id" {
  description = "Haven private network ID"
  type        = string
}

variable "labels" {
  description = "Common labels applied to all resources"
  type        = map(string)
  default     = {}
}
