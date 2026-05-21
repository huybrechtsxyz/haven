# =============================================================================
# Kamatera VMs Module — Variables
# =============================================================================

variable "workspace_name" {
  description = "Workspace name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (production, staging, etc.)"
  type        = string
}

variable "region" {
  description = "Kamatera region code (e.g. eu-fr)"
  type        = string
}

variable "vm_instances" {
  description = "Flattened VM instances map: { key => { resource, role, index, provider } }"
  type = map(object({
    resource = string
    role     = string
    index    = number
    provider = string
  }))
}

variable "vm_resources" {
  description = "VM resource definitions (from resources variable)"
  type = map(object({
    type        = string
    provider    = string
    category    = string
    subcategory = string
    unit_cost   = number
    description = optional(string, "")
    labels      = optional(map(string), {})
    tags        = optional(list(string), [])
    configuration = optional(object({
      os_name   = string
      os_code   = string
      cpu_type  = string
      cpu_cores = number
      ram_mb    = number
      billing   = string
      disk_size = optional(number)
    }))
    storage = optional(object({
      install_path = string
      disks = list(object({
        size  = number
        label = string
        mount = string
      }))
      volumes = optional(list(object({
        name = string
        path = string
      })), [])
    }))
    firewall = optional(string)
  }))
}

variable "firewalls" {
  description = "Firewall rule sets for VMs"
  type = map(object({
    description = optional(string, "")
    labels      = optional(map(string), {})
    tags        = optional(list(string), [])
    rules = object({
      reset    = bool
      defaults = list(any)
      deny     = list(any)
      allow    = list(any)
    })
  }))
  default = {}
}

variable "kamatera_api_key" {
  description = "Kamatera API key"
  type        = string
  sensitive   = true
}

variable "kamatera_api_secret" {
  description = "Kamatera API secret"
  type        = string
  sensitive   = true
}

variable "kamatera_root_password" {
  description = "Root password for server provisioning"
  type        = string
  sensitive   = true
}

variable "kamatera_private_key" {
  description = "SSH private key for server access"
  type        = string
  sensitive   = true
}

variable "kamatera_public_key" {
  description = "SSH public key for server access"
  type        = string
  sensitive   = true
}
