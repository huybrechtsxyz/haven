# Domain Configuration — huybrechts.xyz

This document contains the domain registration and DNS record configuration specific to the **huybrechts.xyz** deployment.

## Registered Domains

The haven deployment uses four domains registered at INWX:

| Domain           | Registrar | Primary Use    | Notes                         |
| ---------------- | --------- | -------------- | ----------------------------- |
| `huybrechts.xyz` | INWX      | Haven platform | Primary domain                |
| `huybrechts.dev` | INWX      | Development    | HSTS-preloaded                |
| `alderwyn.xyz`   | INWX      | —              | Reserved                      |
| `madebyjana.be`  | INWX      | Static site    | Daughter's website (no email) |

**Registrar:** INWX (<https://www.inwx.de>)  
**Nameservers:** INWX defaults (`ns.inwx.net`, `ns2.inwx.net`, `ns3.inwx.eu`)

## DNS Records for huybrechts.xyz

Add these DNS records at INWX (Domains → `huybrechts.xyz` → DNS Records):

| Type | Name                             | Priority | Value                                     | TTL  | Notes                                                                                 |
| ---- | -------------------------------- | -------- | ----------------------------------------- | ---- | ------------------------------------------------------------------------------------- |
| A    | `huybrechts.xyz`                 |          | `<server-ip-address>`                     | 3600 | Root domain pointing to the hearth VPS (Caddy reverse proxy)                          |
| A    | `auth.huybrechts.xyz`            |          | `<server-ip-address>`                     | 3600 | Subdomain for Authentik service (SSO)                                                 |
| A    | `vault.huybrechts.xyz`           |          | `<server-ip-address>`                     | 3600 | Subdomain for Vaultwarden service (password manager)                                  |
| A    | `secrets.huybrechts.xyz`         |          | `<server-ip-address>`                     | 3600 | Subdomain for secrets management service                                              |
| A    | `portainer.huybrechts.xyz`       |          | `<server-ip-address>`                     | 3600 | Subdomain for Portainer service (container management)                                |
| A    | `wud.huybrechts.xyz`             |          | `<server-ip-address>`                     | 3600 | Subdomain for WUD service                                                             |
| CAA  | `huybrechts.xyz`                 |          | `128 issue "letsencrypt.org"`             | 3600 | CAA record to allow Let's Encrypt to issue TLS certificates for the domain            |
| MX   | `huybrechts.xyz`                 | 10       | `mail.huybrechts.xyz`                     | 3600 | MX record pointing to the mail server (Infomaniak)                                    |
| TXT  | `huybrechts.xyz`                 |          | `v=spf1 include:mail.infomaniak.ch ~all`  | 3600 | SPF record to authorize Infomaniak mail servers to send email on behalf of the domain |
| TXT  | `mail._domainkey.huybrechts.xyz` |          | `v=DKIM1; k=rsa; p=...` (from Infomaniak) | 3600 | DKIM record for email authentication (value provided by Infomaniak)                   |

**MX and TXT records:** Add the mail (MX, TXT, DKIM) records once the Hearth VPS is provisioned and you know its IP address. See [infomaniak.md](./infomaniak.md) for email configuration details.

## DNSSEC — Critical Warning

> ⚠️ **Never enable DNSSEC at INWX for `huybrechts.xyz`.**
>
> **Problem:** INWX creates DS records at the `.xyz` TLD registry but does NOT automatically install corresponding DNSKEY records in the zone. This creates a broken DNSSEC chain.
>
> **Result:** Validating resolvers (Google 8.8.8.8, Cloudflare 1.1.1.1) return `SERVFAIL` → Caddy ACME challenges fail → no TLS certificates are issued.
>
> **If accidentally enabled:** Go to INWX → Domains → `huybrechts.xyz` → DNSSEC → delete ALL keys. Changes propagate in ~1 hour.
