# =============================================================================
# Module: Forge — Input Variables
# =============================================================================

variable "resource_config" {
  description = "VM resource definition from strata build output"
  type = object({
    type        = string
    provider    = string
    category    = string
    subcategory = string
    unit_cost   = number
    description = optional(string, "")
    labels      = optional(map(string), {})
    tags        = optional(list(string), [])
    configuration = object({
      server_type = string
      image       = string
      location    = string
      type        = optional(string)
    })
    storage = optional(object({
      install_path = string
      volumes = optional(list(object({
        name = string
        path = string
      })), [])
    }))
    firewall = optional(string)
  })
}

variable "firewall_config" {
  description = "Firewall definition from strata build output"
  type = object({
    description = optional(string, "")
    labels      = optional(map(string), {})
    tags        = optional(list(string), [])
    rules = object({
      reset = bool
      defaults = list(object({
        direction  = string
        permission = string
        comment    = optional(string, "")
      }))
      deny = list(any)
      allow = list(object({
        direction = string
        proto     = optional(string)
        port      = optional(list(number))
        from      = optional(string)
        interface = optional(string)
        comment   = optional(string, "")
      }))
    })
  })
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

variable "workspace_name" {
  description = "Workspace name — used as resource name prefix"
  type        = string
}
