# Domain Configuration

This document describes domain registration and DNS record configuration for a Haven deployment.

## Registered Domains

A typical Haven deployment uses multiple domains registered at INWX:

| Domain                            | Registrar | Primary Use     | Notes                                 |
| --------------------------------- | --------- | --------------- | ------------------------------------- |
| `{base-domain}` (e.g., `.xyz`)    | INWX      | Haven platform  | Primary mail and services             |
| `{sandbox-domain}` (e.g., `.dev`) | INWX      | Development     | HSTS-preloaded; HTTPS mandatory       |
| `{alias-domain-1}`                | INWX      | Mail forwarding | Brand variant or legacy name          |
| `{alias-domain-2}`                | INWX      | Mail forwarding | Additional alias (add more as needed) |
| `{static-site-domain}`            | INWX      | Static content  | Portfolio, blog, etc. (no email)      |

**Registrar:** INWX (<https://www.inwx.de>)  
**Nameservers:** INWX defaults (`ns.inwx.net`, `ns2.inwx.net`, `ns3.inwx.eu`) or custom

## DNS Records for Base Domain

Add these DNS records at INWX (Domains → `{base-domain}` → DNS Records):

| Type | Name                            | Priority | Value                                    | TTL  | Notes                                                    |
| ---- | ------------------------------- | -------- | ---------------------------------------- | ---- | -------------------------------------------------------- |
| A    | `{base-domain}`                 |          | `<hearth-ip>`                            | 3600 | Root domain pointing to Hearth VPS (Caddy reverse proxy) |
| A    | `auth.{base-domain}`            |          | `<hearth-ip>`                            | 3600 | Authentik (SSO)                                          |
| A    | `vault.{base-domain}`           |          | `<hearth-ip>`                            | 3600 | Vaultwarden (password manager)                           |
| A    | `secrets.{base-domain}`         |          | `<hearth-ip>`                            | 3600 | Infisical (secrets management)                           |
| A    | `portainer.{base-domain}`       |          | `<hearth-ip>`                            | 3600 | Portainer (container mgmt)                               |
| A    | `wud.{base-domain}`             |          | `<hearth-ip>`                            | 3600 | WUD (update notifier)                                    |
| A    | `status.{base-domain}`          |          | `<hearth-ip>`                            | 3600 | Gatus (health dashboard)                                 |
| CAA  | `{base-domain}`                 |          | `128 issue "letsencrypt.org"`            | 3600 | Allow Let's Encrypt to issue TLS certificates            |
| MX   | `{base-domain}`                 | 10       | `mail.infomaniak.com`                    | 3600 | MX record pointing to Infomaniak mail servers            |
| TXT  | `{base-domain}`                 |          | `v=spf1 include:mail.infomaniak.ch ~all` | 3600 | SPF record (Infomaniak sender authorization)             |
| TXT  | `mail._domainkey.{base-domain}` |          | `v=DKIM1; k=rsa; p=...`                  | 3600 | DKIM record (value from Infomaniak)                      |

**Mail records:** Configure MX, SPF, and DKIM once Infomaniak kSuite is provisioned. See [guide.md](./guide.md) for setup details.

## DNSSEC — Critical Warning

> ⚠️ **Never enable DNSSEC at INWX for your base domain.**
>
> **Problem:** INWX creates DS records at the TLD registry but does NOT automatically install corresponding DNSKEY records in the zone. This creates a broken DNSSEC chain.
>
> **Result:** Validating resolvers (Google 8.8.8.8, Cloudflare 1.1.1.1) return `SERVFAIL` → Caddy ACME challenges fail → TLS certificates cannot be issued.
>
> **If accidentally enabled:** Go to INWX → Domains → `{base-domain}` → DNSSEC → delete ALL keys. Changes propagate in ~1 hour.
