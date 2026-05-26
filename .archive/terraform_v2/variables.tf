# =============================================================================
# Variables consumed from platform build output (*.auto.tfvars.json)
# =============================================================================

# --- workspace.auto.tfvars.json ---

variable "workspace_name" {
  description = "Platform workspace name"
  type        = string
}

variable "workspace_version" {
  description = "Workspace version from labels"
  type        = string
  default     = "1.0.0"
}

variable "deployment_name" {
  description = "Deployment identifier"
  type        = string
}

variable "environment" {
  description = "Target environment (production, staging, etc.)"
  type        = string
  default     = "production"
}

variable "platform_version" {
  description = "Platform API version"
  type        = string
}

variable "labels" {
  description = "Workspace labels"
  type        = map(string)
  default     = {}
}

variable "metadata" {
  description = "Deployment and workspace metadata"
  type = object({
    deployment_version     = string
    workspace_description  = string
    deployment_description = string
    workspace_tags         = list(string)
    deployment_tags        = list(string)
  })
}

# --- providers.auto.tfvars.json ---

variable "platform_providers" {
  description = "Cloud provider configurations"
  type = map(object({
    type        = string
    region      = string
    engine      = optional(string)
    version     = optional(string)
    description = optional(string)
    labels      = optional(map(string), {})
    tags        = optional(list(string), [])
  }))
}

# --- topologies.auto.tfvars.json ---

variable "topologies" {
  description = "Topology definitions with components and volumes"
  type = map(object({
    type        = string
    provider    = string
    provisioner = string
    components = list(object({
      resource = string
      role     = optional(string)
      count    = optional(number, 1)
    }))
    volumes = optional(list(object({
      name = string
      type = string
    })), [])
  }))
}

# --- resx_virtualmachine.auto.tfvars.json ---

variable "resources" {
  description = "Virtual machine resource definitions"
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

# --- modules.auto.tfvars.json ---

variable "modules" {
  description = "Service module definitions"
  type = map(object({
    repository  = string
    source_path = string
    target_path = optional(string)
    description = optional(string, "")
    labels      = optional(map(string), {})
    tags        = optional(list(string), [])
    properties  = optional(any, {})
  }))
  default = {}
}

# --- namespaces.auto.tfvars.json ---

variable "namespaces" {
  description = "Namespace definitions with module assignments"
  type = map(object({
    description = optional(string, "")
    labels      = optional(map(string), {})
    tags        = optional(list(string), [])
    modules     = optional(list(string), [])
  }))
  default = {}
}

# --- firewalls.auto.tfvars.json ---

variable "firewalls" {
  description = "Merged firewall rule sets per VM"
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

# =============================================================================
# Secrets — injected as TF_VAR_* environment variables by the deploy command
# =============================================================================

variable "KAMATERA_API_KEY" {
  description = "Kamatera API key"
  type        = string
  sensitive   = true
}

variable "KAMATERA_API_SECRET" {
  description = "Kamatera API secret"
  type        = string
  sensitive   = true
}

variable "KAMATERA_PRIVATE_KEY" {
  description = "SSH private key for server access"
  type        = string
  sensitive   = true
}

variable "KAMATERA_PUBLIC_KEY" {
  description = "SSH public key for server access"
  type        = string
  sensitive   = true
}

variable "KAMATERA_ROOT_PASSWORD" {
  description = "Root password for server provisioning"
  type        = string
  sensitive   = true
}

variable "TERRAFORM_API_TOKEN" {
  description = "Terraform Cloud API token"
  type        = string
  sensitive   = true
}

# =============================================================================
# Constants — injected as TF_VAR_* from tf_required_variables.json
# =============================================================================

variable "WORKSPACE" {
  description = "Workspace constant from environment"
  type        = string
  default     = ""
}

variable "DATACENTER" {
  description = "Datacenter constant from environment"
  type        = string
  default     = ""
}
