# Haven Domains

> This document describes domain registration and DNS record configuration for a Haven deployment.

[← Back to Guide](./index.md)

## Domain Registration or Transfer

> **ACTION:** Register or transfer your domains to INWX, then configure the DNS records as described in the next section. Before doing this, decide on your primary domain and subdomain structure.

Register or transfer your domain(s) to **INWX** (or your preferred INWX-compatible registrar). Haven is designed to work with domains managed at INWX for DNS automation.

For detailed instructions on registering or transferring domains at INWX, see **[inwx.md](./services/inwx.md#domain-registration-or-transfer)**.

Before registering or transferring domains, decide on:

1. **Primary domain:** The main domain where Caddy will host your services (auth, vaults, etc.). Choose a domain you're comfortable with long-term.
2. **Subdomains:** You'll need one subdomain per service (e.g., `auth.{domain}`, `vault.{domain}`). Caddy's auto-TLS covers all subdomains with wildcard certificates.
3. **Domain configuration:** See below for a concrete example with specific domains, subdomains, and DNS records.

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

## DNS Records for Forge

Add these DNS records at INWX (Domains → `{base-domain}` → DNS Records). Unlike the base-domain records above, these point to the **Forge** VPS, not Hearth — Traefik (on Forge) terminates TLS for these, not Caddy:

| Type | Name                   | Priority | Value        | TTL  | Notes                        |
| ---- | ---------------------- | -------- | ------------ | ---- | ---------------------------- |
| A    | `photos.{base-domain}` |          | `<forge-ip>` | 3600 | Immich (photo/video library) |
| A    | `media.{base-domain}`  |          | `<forge-ip>` | 3600 | Jellyfin (media streaming)   |
| A    | `docs.{base-domain}`   |          | `<forge-ip>` | 3600 | Nextcloud (document archive) |
| A    | `books.{base-domain}`  |          | `<forge-ip>` | 3600 | Kavita (books/PDFs/EPUBs)    |

## DNSSEC — Critical Warning

> ⚠️ **Never enable DNSSEC at INWX for your base domain.**
>
> **Problem:** INWX creates DS records at the TLD registry but does NOT automatically install corresponding DNSKEY records in the zone. This creates a broken DNSSEC chain.
>
> **Result:** Validating resolvers (Google 8.8.8.8, Cloudflare 1.1.1.1) return `SERVFAIL` → Caddy ACME challenges fail → TLS certificates cannot be issued.
>
> **If accidentally enabled:** Go to INWX → Domains → `{base-domain}` → DNSSEC → delete ALL keys. Changes propagate in ~1 hour.
