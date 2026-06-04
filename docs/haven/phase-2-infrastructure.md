# Phase 2 — Infrastructure Provisioning

> [← Phase 1](phase-1-dns-domain.md) | [Next: Phase 3 — Hearth Init →](phase-3-hearth-init.md)

Provision the Hetzner VPS, firewall, and private network using strata + Terraform.

**Automated:** Terraform via strata build + GitHub Actions.  
**Manual step required:** Order Hetzner Storage Box (no API exists).  
**Estimated time:** 20 minutes (excluding Storage Box delivery).

---

## 2.1 — Order Hetzner Storage Box (manual, one-time)

> **⚠️ This cannot be automated.** Hetzner Storage Boxes are managed through
> [Hetzner Robot](https://robot.hetzner.com), which has no API, no CLI, and no Terraform provider.

1. Go to [robot.hetzner.com](https://robot.hetzner.com) → **Storage Box**
2. Order **BX11** (1 TB, ~€3.81/mo), location: **Nuremberg** (same region as VPS)
3. Once activated, go to the Storage Box settings and create a sub-account:
   - Username: `hearth_backup`
   - Permissions: SSH access enabled
4. Note the hostname (e.g., `uXXXXXX.your-storagebox.de`) — needed for Phase 6 (BorgBackup)

The strata config `config/hearth/sb-hetzner-hearth.yaml` documents the spec for inventory purposes but does **not** provision it.

---

## 2.2 — Understand the strata build

The haven repo uses `strata` to generate Terraform tfvars from the YAML config files:

```
config/deploy-haven-prd.yaml   ← deployment definition
config/env-haven-prd.yaml      ← environment variables and secrets mapping
config/ws-haven.yaml           ← workspace definition
config/cfg-haven.yaml          ← platform config
config/hearth/vm-hetzner-hearth.yaml  ← VPS spec (CX23, Nuremberg, Ubuntu 24.04)
config/hearth/fw-hetzner-hearth.yaml  ← firewall rules
```

Build output goes to: `build/haven_deploy_prd-1.0.0/terraform/`

---

## 2.3 — What Terraform provisions

The `terraform/` directory (and modules `forge/` + `hearth/`) create:

| Resource | Details |
|----------|---------|
| Hetzner VPS | CX23 (2 vCPU, 4 GB RAM, 40 GB SSD), Nuremberg, Ubuntu 24.04 |
| SSH key | Uploaded from `HETZNER_PUBLIC_KEY` |
| Firewall | Inbound: 80/TCP, 443/TCP, 22/TCP (restricted). Outbound: all |
| Private network | `10.0.0.0/8`, subnet `10.0.1.0/24` |
| Server attachment | VPS attached to private network |

---

## 2.4 — First-time local run

For the very first provisioning (or after destroying infrastructure), run locally:

```powershell
cd E:\SourcesXYZ\haven

# Build strata artifacts
strata build run -f config/deploy-haven-prd.yaml

# Set required environment variables
$env:TF_VAR_HETZNER_API_TOKEN     = "your-token"
$env:TF_VAR_HETZNER_PUBLIC_KEY    = Get-Content ~/.ssh/haven_ed25519.pub -Raw
$env:TF_VAR_HETZNER_PRIVATE_KEY   = Get-Content ~/.ssh/haven_ed25519 -Raw
$env:TF_VAR_HETZNER_ROOT_PASSWORD = "your-root-password"

# Copy generated tfvars
Copy-Item build\haven_deploy_prd-1.0.0\terraform\*.auto.tfvars.json terraform\

# Init and apply
cd terraform
tofu init
tofu plan
tofu apply
```

Note the outputs after apply:

```
hearth_public_ip  = "91.98.78.36"   ← use this for DNS A records (Phase 1)
```

---

## 2.5 — Subsequent runs via GitHub Actions

After the first successful local run, all future deployments use GitHub Actions:

```
git push → .github/workflows/deploy.yml → strata build + tofu apply + ansible
```

The workflow requires the `production` environment secrets to be set (Phase 0).

To trigger manually: **Actions → Deploy Haven → Run workflow**.

---

## 2.6 — Verify

```powershell
# SSH to the new server (replace with your private key path)
ssh -i ~/.ssh/haven_ed25519 root@91.98.78.36

# Check it's the right server
uname -a    # Linux, Ubuntu 24.04
df -h       # ~40 GB root disk
```

---

## Checklist

- [ ] Hetzner Storage Box ordered (BX11, Nuremberg)
- [ ] Storage Box sub-account `hearth_backup` created with SSH access
- [ ] `strata build run` completed without errors
- [ ] `tofu apply` completed — `hearth_public_ip` noted
- [ ] Can SSH to the server as root
- [ ] DNS A records updated with the server IP (Phase 1)
