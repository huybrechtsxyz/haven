# =============================================================================
# Haven Platform — Root Variables (not from strata)
# =============================================================================
# Static network settings with defaults. Everything strata delivers is taken in
# by strata.tf and exposed as locals.
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
