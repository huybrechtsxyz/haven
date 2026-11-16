# =============================================================================
# Strata adapter — the ONLY file in this root that knows strata exists
# =============================================================================
# `strata build run` writes one `strata` object into strata.auto.tfvars.json,
# and `strata deploy run` sets TF_VAR_<KEY> for every resolved value (secrets
# included). This file takes both in and maps them onto plain `local.*` values;
# main.tf, versions.tf, outputs.tf and the modules read only those locals.
#
# Declaring `variable "strata"` here is strata's documented opt-out of its
# generated strata_variables.tf / strata_locals.tf. That keeps this root
# self-contained, so `terraform init -backend=false && terraform validate`
# work on the source folder (ci-build.yml) without a strata build. The opt-out
# also means `${secret:...}` tokens inside strata documents are not merged
# into the payload; this root takes its secrets as TF_VAR_<KEY> below instead.
#
# The type lists only the fields this root reads. Terraform discards every
# other attribute strata sends, so the payload can grow without breaking this.
# =============================================================================

variable "strata" {
  description = "Strata payload (strata.auto.tfvars.json, written by `strata build run`)."
  type = object({
    workspace = object({
      name       = string
      version    = optional(string, "1.0.0")
      deployment = string
    })

    # Deployment properties, merged workspace -> environments -> deployment.
    properties = object({
      environment = string
    })

    # Workspace resource instances, keyed by instance name (hearth, forge).
    resources = map(object({
      resource_type = string
      configuration = object({
        server_type = string
        image       = string
        location    = string
      })
      storage = object({
        install_path = string
      })
      firewalls = list(string)
    }))

    # Firewall documents, keyed by name (hearth-firewall, forge-firewall).
    firewalls = map(object({
      rules = object({
        allow = list(object({
          direction = string
          proto     = optional(string)
          port      = optional(list(string))
          from      = optional(string)
          to        = optional(string)
          interface = optional(string)
          comment   = optional(string, "")
        }))
      })
    }))
  })
}

# Secrets — strata sets TF_VAR_<KEY> for every value of the deployment's
# environments; Terraform reads only the ones declared here.

variable "HETZNER_API_TOKEN" {
  description = "Hetzner Cloud API token (environment secret HETZNER_API_TOKEN)."
  type        = string
  sensitive   = true
}

variable "HETZNER_PUBLIC_KEY" {
  description = "SSH public key installed on every VM (environment secret HETZNER_PUBLIC_KEY)."
  type        = string
  sensitive   = true
}

locals {
  workspace_name  = var.strata.workspace.name
  workspace_ver   = var.strata.workspace.version
  deployment_name = var.strata.workspace.deployment
  environment     = var.strata.properties.environment

  hcloud_token   = var.HETZNER_API_TOKEN
  ssh_public_key = var.HETZNER_PUBLIC_KEY

  # One entry per virtual machine, keyed by workspace instance name. Each
  # carries its server settings and the rules of its firewall(s), already
  # flattened to what a cloud firewall can express:
  #   - only rules with a protocol (interface-only rules such as `lo` are
  #     OS-level, a cloud firewall never sees that traffic);
  #   - `cidrs` is the rule's `from` (inbound) or `to` (outbound), or every
  #     address when the rule names none;
  #   - `ports` keeps the document's list (["53"], ["20", "21"], ["80:90"]).
  vms = {
    for name, res in var.strata.resources : name => {
      server_type  = res.configuration.server_type
      image        = res.configuration.image
      location     = res.configuration.location
      install_path = res.storage.install_path
      firewall_rules = flatten([
        for fw in res.firewalls : [
          for rule in var.strata.firewalls[fw].rules.allow : {
            direction   = rule.direction
            protocol    = rule.proto
            ports       = coalesce(rule.port, [])
            cidrs       = (rule.direction == "in" ? rule.from : rule.to) != null ? [rule.direction == "in" ? rule.from : rule.to] : ["0.0.0.0/0", "::/0"]
            description = rule.comment
          }
          if rule.proto != null && rule.interface == null
        ]
      ])
    }
    if res.resource_type == "virtualmachine"
  }
}
