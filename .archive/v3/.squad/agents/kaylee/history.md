# Kaylee — Project History

## Project Context (day-1 seed)

- **Project:** Haven — family IT platform for 5 users (Huybrechts family)
- **Owner:** Vincent Huybrechts
- **Hetzner region:** eu-de, location nbg1 (Nuremberg)
- **VMs:**
  - Hearth: CX22 (2 vCPU, 4 GB RAM, 40 GB SSD) — ~€4.15/mo — Docker Compose node
  - Forge: CPX41 (8 vCPU, 16 GB RAM, 240 GB SSD) — ~€26/mo — k3s node
  - Storage Box: BX11 (1 TB) — ~€3.81/mo — BorgBackup target, SSH access
- **Stack files (2026-05-29):**
  - `stack/dc-hetzner-eu-de.yaml` — provider definition (hetzner_dc_eu_de)
  - `stack/vm-hetzner-hearth.yaml` — Hearth VM (haven_vm_hetzner_hearth)
  - `stack/vm-hetzner-forge.yaml` — Forge VM (haven_vm_hetzner_forge)
  - `stack/fw-hetzner-hearth.yaml` — Hearth firewall (haven_fw_hetzner_hearth)
  - `stack/fw-hetzner-forge.yaml` — Forge firewall (haven_fw_hetzner_forge)
  - `stack/sb-hetzner-hearth.yaml` — Storage Box (haven_sb_hetzner_hearth)
  - `stack/ws-family-platform.yaml` — workspace (haven_family_platform)
- **apiVersion:** strata.huybrechts.xyz/v1 (not yet platform.huybrechts.xyz/v1 — schema update pending)
- **Domains (at INWX):** huybrechts.xyz (primary), huybrechts.dev, alderwyn.xyz, madebyjana.be
- **Wave 1 status:** Domain transfers initiated 2026-05-27; Hetzner not yet provisioned

## Learnings

### 2026-05-29 — Terraform root module for Hearth (Hetzner Cloud)

Built `terraform/` with four files: `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`.

**What it provisions:**
- SSH key (from GitHub Secrets via TF_VAR_HETZNER_PUBLIC_KEY)
- Private network (10.0.0.0/8) with /24 subnet in eu-central zone
- Hearth VPS (CX22, ubuntu-24.04, nbg1) with prevent_destroy lifecycle
- Firewall: default-deny in+out, allows HTTP/HTTPS in, SSH from private net only, DNS/NTP/apt/HTTPS out
- Server-network attachment for private IP

**Key decisions:**
- Kept the strata auto.tfvars.json variable contract from v2 (`workspace_name`, `resources`, `firewalls`, etc.) but adapted `resources.configuration` from Kamatera shape (cpu_type/ram_mb/billing) to Hetzner shape (server_type/image/location)
- Firewall rules are hardcoded in main.tf rather than dynamically generated from `var.firewalls` — keeps it readable for a 2-server platform; can be made dynamic when Forge joins
- Loopback rules from fw-hetzner-hearth.yaml skipped — hcloud firewalls don't support interface-based rules (those are OS-level nftables)
- No hcloud_volume resources — the 40GB CX22 root disk is sufficient; /opt/haven/* paths are directories, not block volumes
- Storage Box (BX11) noted in outputs.tf as a placeholder — not provisionable via hcloud provider
- Local state backend — no Terraform Cloud (that was Kamatera-era)
- cloud-init creates /opt/haven directory tree on first boot
- Port array [20, 21] mapped to port range "20-21" for hcloud compatibility
