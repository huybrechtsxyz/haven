# Phase 1 — DNS & Domain

> [← Phase 0](phase-0-prerequisites.md) | [Next: Phase 2 — Infrastructure →](phase-2-infrastructure.md)

Set up DNS at INWX so all Hearth subdomains resolve to the server.

**Automated:** Nothing — DNS is fully manual.  
**Estimated time:** 15 minutes.

---

## 1.1 — Add DNS A records

After provisioning the VPS (Phase 2), you will have a public IP. Add these A records in the INWX DNS panel for `huybrechts.xyz`:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `huybrechts.xyz` | `<server-ip>` | 300 |
| A | `auth.huybrechts.xyz` | `<server-ip>` | 300 |
| A | `vault.huybrechts.xyz` | `<server-ip>` | 300 |
| A | `secrets.huybrechts.xyz` | `<server-ip>` | 300 |

> Increase TTL to 3600 once everything is verified and stable.

**Current server IP:** `91.98.78.36`

---

## 1.2 — Verify DNS propagation

```powershell
# Check from your workstation
Resolve-DnsName -Name auth.huybrechts.xyz -Type A
Resolve-DnsName -Name vault.huybrechts.xyz -Type A
Resolve-DnsName -Name secrets.huybrechts.xyz -Type A
```

All should return `91.98.78.36` (or your new server IP).

---

## ⚠️ 1.3 — Do NOT enable DNSSEC

> **This is the single most important gotcha in the entire setup.**

INWX offers an "Auto-generate DNSSEC" option. **Do not use it.**

**Why it breaks Let's Encrypt:**
- INWX creates DS records at the `.xyz` TLD registry
- INWX does NOT automatically install the corresponding DKEY records in the zone
- This creates a broken DNSSEC chain
- Let's Encrypt uses DNSSEC-validating resolvers (Google 8.8.8.8, Cloudflare 1.1.1.1)
- Those resolvers return `SERVFAIL` for your domain
- Caddy ACME challenges fail → no TLS certificates → services are unreachable

**If DNSSEC is already enabled:**

1. INWX console → Domains → `huybrechts.xyz` → DNSSEC
2. Delete ALL DNSSEC keys
3. This removes the DS record from the `.xyz` TLD registry (takes ~1 hour to propagate)

**Verify DNSSEC is clean:**

```powershell
# Should return SOA (no DS record) — not a DS record
Resolve-DnsName -Name huybrechts.xyz -Type DS -Server "x.nic.xyz"
```

If it returns `SOA` → clean. If it returns a `DS` record → DNSSEC is still active.

---

## 1.4 — Verify DNS before deploying services

Run this before triggering the GitHub Actions pipeline:

```powershell
# All must return the correct IP
foreach ($host in @("auth","vault","secrets")) {
    $result = Resolve-DnsName "$host.huybrechts.xyz" -Type A -ErrorAction SilentlyContinue
    Write-Host "$host.huybrechts.xyz -> $($result.IPAddress)"
}
```

---

## Checklist

- [ ] A records added for `auth`, `vault`, `secrets` subdomains
- [ ] DNS propagation verified (all return correct IP)
- [ ] DNSSEC **not** enabled (or disabled and DS record removed)
