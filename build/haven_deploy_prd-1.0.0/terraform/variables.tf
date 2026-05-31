# =============================================================================
# Variables consumed from strata build output (*.auto.tfvars.json)
# =============================================================================
# Strata's `build` command generates JSON files that OpenTofu auto-loads.
# Variable shapes match the strata v0.0.3 build contract exactly.
#
# Build output: build/{deployment}-{version}/terraform/
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
  description = "Target environment"
  type        = string
  default     = "production"
}

variable "platform_version" {
  description = "Platform API version"
  type        = string
  default     = "strata.huybrechts.xyz/v1"
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
  description = "Topology definitions"
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

# --- resx_virtualmachine.auto.tfvars.json + resx_storagebox.auto.tfvars.json ---
# Both files use "resources" as the key. OpenTofu merges maps across tfvars files.

variable "resources" {
  description = "Resource definitions (VMs and storage boxes)"
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
      server_type = optional(string)
      image       = optional(string)
      location    = optional(string)
      type        = optional(string) # storagebox type (bx11)
    }))
    storage = optional(object({
      install_path = string
      volumes = optional(list(object({
        name = string
        path = string
      })), [])
    }))
    firewall = optional(string)
  }))
}

# --- firewalls.auto.tfvars.json ---

variable "firewalls" {
  description = "Firewall rule sets"
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

# --- modules.auto.tfvars.json ---

variable "modules" {
  description = "Module definitions (empty for now)"
  type        = map(any)
  default     = {}
}

# --- namespaces.auto.tfvars.json ---

variable "namespaces" {
  description = "Namespace definitions (empty for now)"
  type        = map(any)
  default     = {}
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_cidr" {
  description = "Private network CIDR"
  type        = string
  default     = "10.0.0.0/8"
}

variable "subnet_cidr" {
  description = "Subnet CIDR within the private network"
  type        = string
  default     = "10.0.1.0/24"
}

variable "network_zone" {
  description = "Hetzner network zone"
  type        = string
  default     = "eu-central"
}

# =============================================================================
# Secrets — injected as TF_VAR_* (from tf_required_secrets.json)
# =============================================================================

variable "HETZNER_API_TOKEN" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "HETZNER_PUBLIC_KEY" {
  description = "SSH public key for server access"
  type        = string
  sensitive   = true
}

variable "HETZNER_PRIVATE_KEY" {
  description = "SSH private key (used by Ansible)"
  type        = string
  sensitive   = true
}

variable "HETZNER_ROOT_PASSWORD" {
  description = "Root password for initial provisioning"
  type        = string
  sensitive   = true
}

variable "INFISICAL_ESO_TOKEN" {
  description = "Infisical token for ESO (Forge/k3s — Wave 2)"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Environment variables — from tf_required_variables.json
# =============================================================================

variable "WORKSPACE" {
  type    = string
  default = "haven"
}

variable "DATACENTER" {
  type    = string
  default = "hetzner-eu-de"
}

variable "ENVIRONMENT" {
  type    = string
  default = "prd"
}

variable "DOMAIN_PRIMARY" {
  type    = string
  default = "huybrechts.xyz"
}

variable "DOMAIN_ALIAS_DEV" {
  type    = string
  default = "huybrechts.dev"
}

variable "DOMAIN_ALIAS_ALDERWYN" {
  type    = string
  default = "alderwyn.xyz"
}

variable "DOMAIN_ALIAS_JANA" {
  type    = string
  default = "madebyjana.be"
}

variable "SUBDOMAIN_AUTH" {
  type    = string
  default = "auth.huybrechts.xyz"
}

variable "SUBDOMAIN_VAULT" {
  type    = string
  default = "vault.huybrechts.xyz"
}

variable "SUBDOMAIN_SECRETS" {
  type    = string
  default = "secrets.huybrechts.xyz"
}

variable "SUBDOMAIN_PHOTOS" {
  type    = string
  default = "photos.huybrechts.xyz"
}

variable "SUBDOMAIN_STATUS" {
  type    = string
  default = "status.huybrechts.xyz"
}

variable "HETZNER_REGION" {
  type    = string
  default = "eu-de"
}

variable "HETZNER_LOCATION" {
  type    = string
  default = "nbg1"
}

variable "CORE_VM_TYPE" {
  type    = string
  default = "cx22"
}

variable "WORKLOAD_VM_TYPE" {
  type    = string
  default = "cpx41"
}

variable "STORAGE_BOX_TYPE" {
  type    = string
  default = "bx11"
}
