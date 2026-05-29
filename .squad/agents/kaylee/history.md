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
