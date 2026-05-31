# Decision: Terraform Hearth Root Module — Design Choices

**Date:** 2026-05-29  
**Author:** Kaylee  
**Status:** Proposed — awaiting Mal review  

## Context

Built the Terraform root module for Hearth-only provisioning on Hetzner Cloud (`terraform/`). Several design choices were made that affect future extensibility.

## Decisions Made

### 1. Firewall rules hardcoded vs dynamic

Hearth firewall rules are written as static `rule {}` blocks in `main.tf` rather than dynamically iterating over `var.firewalls`. This is simpler and more readable for a 2-server setup. When Forge joins (Wave 2), we should evaluate whether to refactor into dynamic blocks that consume the strata-generated `firewalls.auto.tfvars.json`.

### 2. No Hetzner block volumes

The /opt/haven directory tree lives on the 40GB root disk. No separate `hcloud_volume` resources. If Hearth's data grows beyond root disk capacity, we add volumes then — but for Caddy/Authentik/Vaultwarden/Infisical the root disk is plenty.

### 3. Storage Box is out of Terraform scope

BX11 Storage Boxes can't be managed by the hcloud provider. They need Robot API or console provisioning. Documented in `outputs.tf` as a reminder.

### 4. Local state backend

No remote state backend. State file lives alongside the repo (gitignored). Can migrate to S3-compatible (Hetzner Object Storage) or HCP Terraform later.

### 5. Strata variable contract preserved

Variable shapes match the v2 strata contract (`workspace_name`, `platform_providers`, `topologies`, `resources`, `firewalls`). The `resources.configuration` object was adapted from Kamatera (cpu_type/ram_mb) to Hetzner (server_type/image/location). Strata's `build` command should generate compatible auto.tfvars.json.

## Open Questions for Mal

- Should we add a `.gitignore` in `terraform/` for state files and `.terraform/` directory?
- When Forge arrives, do we want dynamic firewall blocks or keep them static per server?
- Should we pin the hcloud provider more tightly than `~> 1.49`?
