# =============================================================================
# Haven Platform — Root Variables
# =============================================================================
# Complex variables are auto-populated by `strata build` into
# *.auto.tfvars.json — do not edit those files manually.
# Secrets are injected at deploy time via TF_VAR_* environment variables.
# =============================================================================

# =============================================================================
# Workspace Metadata  (workspace.auto.tfvars.json)
# =============================================================================

variable "workspace_name" {
  description = "Workspace name — used as resource name prefix"
  type        = string
}

variable "workspace_version" {
  description = "Workspace schema version"
  type        = string
}

variable "deployment_name" {
  description = "Deployment identifier"
  type        = string
}

variable "environment" {
  description = "Target environment (production, staging, …)"
  type        = string
}

variable "platform_version" {
  description = "Strata platform API version"
  type        = string
}

variable "labels" {
  description = "Common labels applied to all Hetzner resources"
  type        = map(string)
  default     = {}
}

variable "metadata" {
  description = "Deployment metadata from strata build"
  type = object({
    deployment_version     = string
    workspace_description  = optional(string, "")
    deployment_description = optional(string, "")
    workspace_tags         = optional(list(string), [])
    deployment_tags        = optional(list(string), [])
  })
}

# =============================================================================
# Infrastructure Resources  (resx_virtualmachine.auto.tfvars.json)
# =============================================================================

variable "resources" {
  description = "VM resource definitions keyed by resource name"
  type = map(object({
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
  }))
  default = {}
}

# =============================================================================
# Firewalls  (firewalls.auto.tfvars.json)
# =============================================================================

variable "firewalls" {
  description = "Firewall definitions keyed by firewall name"
  type = map(object({
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
        port      = optional(any)
        from      = optional(string)
        interface = optional(string)
        comment   = optional(string, "")
      }))
    })
  }))
  default = {}
}

# =============================================================================
# Topologies  (topologies.auto.tfvars.json)
# =============================================================================

variable "topologies" {
  description = "Topology definitions keyed by topology name"
  type = map(object({
    type        = string
    provider    = string
    provisioner = string
    components = list(object({
      resource = string
      role     = string
      count    = number
    }))
    volumes = optional(list(object({
      name = string
      type = string
    })), [])
  }))
  default = {}
}

# =============================================================================
# Platform Providers  (providers.auto.tfvars.json)
# =============================================================================

variable "platform_providers" {
  description = "Platform provider definitions keyed by provider name"
  type = map(object({
    type        = string
    region      = string
    engine      = optional(string)
    version     = optional(string)
    description = optional(string, "")
    labels      = optional(map(string), {})
    tags        = optional(list(string), [])
  }))
  default = {}
}

# =============================================================================
# Namespaces & Modules  (namespaces.auto.tfvars.json, modules.auto.tfvars.json)
# =============================================================================

variable "namespaces" {
  description = "Namespace definitions (populated in Wave 2 — compose stack)"
  type        = map(any)
  default     = {}
}

variable "modules" {
  description = "Module definitions (populated in Wave 2 — compose stack)"
  type        = map(any)
  default     = {}
}

# =============================================================================
# Network  (not in strata build output — static defaults for Wave 1)
# =============================================================================

variable "network_cidr" {
  description = "CIDR for the Hetzner private network (haven-net)"
  type        = string
  default     = "10.0.0.0/8"
}

variable "network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = "eu-central"
}

variable "subnet_cidr" {
  description = "CIDR for the Hetzner network subnet"
  type        = string
  default     = "10.0.0.0/24"
}

# =============================================================================
# Secrets — injected at deploy time via TF_VAR_* env vars
# =============================================================================

variable "HETZNER_API_TOKEN" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "HETZNER_PUBLIC_KEY" {
  description = "SSH public key deployed to Hetzner VMs"
  type        = string
  sensitive   = true
}

variable "HETZNER_PRIVATE_KEY" {
  description = "SSH private key for Hetzner root access"
  type        = string
  sensitive   = true
}

variable "HEARTH_SSH_PRIVATE_KEY" {
  description = "SSH private key for Hearth VPS (PEM format)"
  type        = string
  sensitive   = true
}

variable "HETZNER_ROOT_PASSWORD" {
  description = "Root password for Hetzner VMs"
  type        = string
  sensitive   = true
}
