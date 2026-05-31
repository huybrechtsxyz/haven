# Hosting Design Specifications

> Source research: [hosting.md](hosting.md)
> Date: 2026-05-26
> Scope: 5 users, family platform, custom email domains with forwarding, EU/Swiss privacy, admin is tech-savvy.

---

## Common assumptions

- **Email is always SaaS** — no self-hosted MTA in any solution. Too much ops overhead (deliverability, IP reputation, spam filtering).
- **Compute** — all self-hosted services run on a single Hetzner VPS (Germany, EU). Admin manages this VPS; family members never interact with it.
- **Domains** — 1 primary email domain + up to 4 alias/forwarder domains. All MX records point to the SaaS mail provider. DNS managed at registrar level.
- **5 mailboxes** — one per family member. Shared calendar and contacts via CalDAV/CardDAV.
- **Password manager** — Vaultwarden on VPS (self-hosted Bitwarden-compatible server). Same Bitwarden app on Firefox and iPhone — zero UX change for family. Saves ~€15/mo vs Bitwarden Team cloud.
- **Secret manager & app config** — Infisical on VPS covers both: per-app/per-environment secrets (API keys, DB passwords) and key-value app configuration (feature flags handled by Flagsmith if needed). No separate Azure App Config / Consul equivalent required. For simple setups start with Bitwarden CLI against Vaultwarden; migrate to Infisical when app count or environment count grows.
- **Photos** — Immich on VPS (Google Photos replacement: timeline, face recognition, shared albums, mobile auto-upload). Free on existing VPS.
- **Backups** — Hetzner Storage Box (BX11 or larger) with BorgBackup/restic for encrypted daily off-server backups. VPS backup includes: Vaultwarden data, Infisical data, Immich library, any app databases, Nextcloud data (Solution 3 only).

### Note on secret managers

HashiCorp was acquired by IBM in April 2024 and changed Vault's licence to BSL (Business Source License) in 2023 — no longer fully open source. Two alternatives:

- **Infisical** ⭐ recommended — MIT-licensed, modern open-source secrets platform with a good UI, per-app/per-environment namespacing, CLI, SDK, Docker Compose deploy, k8s operator and audit log. Self-hostable on the same VPS. Not IBM-controlled.
- **OpenBao** — community-maintained open-source fork of Vault under MPL 2.0, started after the BSL change. Drop-in Vault replacement if Vault-style dynamic credentials or deep ACL policies are needed. Not IBM-controlled.
- **Bitwarden CLI → Vaultwarden** — zero extra service; store secrets as vault items and retrieve with `bw get` in scripts. Works today, good for < ~20 secrets without per-env namespacing.

### Note on app configuration

**What Azure App Configuration / Consul provide:** centralized key-value config store, per-environment overrides (dev/staging/prod), feature flags, dynamic config reload without redeployment, and (in Consul's case) service discovery and health checking.

**Consul note:** same IBM/BSL concern as Vault — Consul was also relicensed to BSL in 2023. Not recommended for new self-hosted setups.

**Open-source alternatives:**

| Tool                    | Licence    | Self-hosted | Best for                                                                                                                                               |
| ----------------------- | ---------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Infisical** ⭐         | MIT        | ✓ Docker    | Covers both secrets AND per-env config key-values in one tool; already recommended for secrets — use it for config too. Avoids adding another service. |
| **Flagsmith**           | BSD-3      | ✓ Docker    | Feature flags + remote config per environment; REST API + SDKs for many languages; good UI; no service discovery.                                      |
| **Unleash**             | Apache 2.0 | ✓ Docker    | Feature toggles focused; well-established; REST API + SDKs; good for gradual rollouts.                                                                 |
| **etcd**                | Apache 2.0 | ✓           | Distributed key-value store; already embedded in k3s/k8s — expose it directly if running k3s. Lightweight but no built-in UI.                          |
| **OpenBao** (KV engine) | MPL 2.0    | ✓           | Vault KV secrets engine also works as a config store; good if already running OpenBao for secrets.                                                     |
| **Zitadel / Ory**       | Apache 2.0 | ✓           | Identity + config — only relevant if also consolidating OIDC/SSO.                                                                                      |

**Recommendation for this stack:**

- **Infisical handles both secrets and app config** — store API keys, DB passwords, and any environment-specific key-value config (base URLs, feature toggles, timeouts) all in one place, separated by app and environment (dev / staging / prod). This replaces Azure App Configuration and removes the need for a separate config service.
- **Add Flagsmith** only if you need a dedicated feature-flag UI with gradual rollout controls, A/B testing, or kill switches — Infisical can toggle boolean config values but has no rollout percentage logic.
- **Use etcd directly** if running k3s/k8s — it is embedded and free; use Kubernetes ConfigMaps for non-sensitive config and Kubernetes Secrets (backed by Infisical via the k8s operator) for sensitive values.
- Avoid Consul (BSL) for new deployments; use **Traefik** or **Caddy** labels for service discovery instead.

### Note on identity (SSO / OIDC)

Home-grown apps and self-hosted services need a central identity provider (IdP) for SSO, 2FA enforcement, OIDC/OAuth2 token issuance and user lifecycle management. Without an IdP every app has its own user database and login — fragile and hard to maintain.

**Keycloak** is the industry-standard open-source IdP (Red Hat / CNCF) — battle-tested, full OIDC/SAML/OAuth2, excellent LDAP/AD federation. However it is Java-based and heavy (~1-2 GB RAM, slow cold start). Still a valid choice if you need SAML or deep enterprise federation.

**Lighter open-source alternatives:**

| Tool            | Licence    | Language    | RAM         | Best for                                                                                                                                                                                       |
| --------------- | ---------- | ----------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Authentik** ⭐ | MIT        | Python + Go | ~300-500 MB | Recommended for self-hosted home/small-team setups; excellent UI, OIDC/SAML/LDAP, proxy provider (can protect any app without native OIDC support), Docker Compose deploy, active development. |
| **Zitadel**     | Apache 2.0 | Go          | ~100-200 MB | Lightest footprint; API-first; OIDC/OAuth2/SAML; good for developer-centric setups and home-grown apps; no proxy provider.                                                                     |
| **Keycloak**    | Apache 2.0 | Java        | ~1-2 GB     | Use if SAML federation, Kerberos, or deep enterprise AD integration is required; otherwise overkill.                                                                                           |
| **Authelia**    | Apache 2.0 | Go          | ~50 MB      | Lightweight 2FA + SSO gateway for reverse proxy (Caddy/Nginx/Traefik); not a full IdP — no OIDC server, no user management API.                                                                |

**What integrates with an IdP (OIDC):** Nextcloud · Immich · Infisical · Vaultwarden (OIDC login) · Flagsmith · home-grown apps (any OAuth2/OIDC library).

**Recommendation:** use **Authentik** on the VPS. Single Docker Compose service, covers all apps via OIDC and the built-in proxy provider, enforces 2FA centrally, and does not require Java. Keycloak is a valid drop-in if SAML or deeper AD/LDAP federation is needed later.

**VPS RAM impact:** add ~400-500 MB for Authentik (or ~1-2 GB for Keycloak). Factor this into VPS sizing — all solutions should use **CPX41 (16 GB)** when running the full stack including identity.

### Note on DNS registrar

DNS has two independent concerns: **domain registration** (whois, EPP transfer, billing) and **authoritative DNS hosting** (nameservers that answer queries). They can be the same provider or different ones.

#### Recommended registrar: INWX

**[INWX](https://www.inwx.com)** ⭐ — German registrar (DE 🇩🇪, GDPR jurisdiction), ICANN-accredited, DNSSEC, clean REST + EPP API, very affordable (~€8-12/yr for `.com`/`.eu`/`.be`/`.nl`/`.xyz`), no per-transfer fees, supports all relevant TLDs. Good balance of EU privacy, API quality and cost.

**Alternative — Infomaniak** (CH 🇨🇭): if using Solution A, consolidating domains with Infomaniak keeps all DNS + mail + files under one vendor (convenience over minimal vendor count). Slightly higher domain prices but excellent UI.

#### Recommended DNS hosting: INWX built-in NS or Hetzner DNS

| Option                    | Cost | Pros                                                                      | Cons                                           |
| ------------------------- | ---- | ------------------------------------------------------------------------- | ---------------------------------------------- |
| **INWX built-in DNS** ⭐   | Free | Single vendor for registration + DNS; API; DNSSEC; no extra login         | Only as reliable as INWX (single anycast zone) |
| **Hetzner DNS**           | Free | Already using Hetzner; REST API; pairs naturally with VPS A records; fast | Separate login; no free secondary NS           |
| **Cloudflare DNS (free)** | Free | Industry-best performance; huge anycast; excellent API + UI               | US company — not EU-native                     |

**Recommendation:** use **INWX built-in DNS** for simplicity. If you want separation of registrar vs DNS hosting, delegate to **Hetzner DNS** (free, API, already in your Hetzner account).

Avoid ClouDNS for new setups — Bulgarian hosting, no EU-specific data residency commitment, and an extra recurring subscription once domains move to INWX.

#### Migrating from Versio (registrar transfer)

Versio is a Dutch registrar. Transfer each domain to INWX:

1. **Lower TTLs** — in Versio DNS manager, set all record TTLs to `300` (5 min) at least 24 h before you start, so DNS changes propagate quickly.
2. **Export DNS records** — screenshot or copy every record (MX, A, CNAME, TXT for SPF/DKIM/DMARC) for each domain. BIND zone export if available.
3. **Recreate records at INWX** — create the domain in INWX DNS and add all records *before* the transfer completes. This prevents downtime when NS changes.
4. **Unlock the domain at Versio** — go to domain settings → remove transfer lock ("Domeindiensten vergrendelen" toggle off).
5. **Request EPP/auth code** — Versio calls this the "authcode". Request it per domain; it arrives by email.
6. **Initiate inbound transfer at INWX** — enter domain + EPP code. INWX sends a confirmation email to the registrant contact.
7. **Confirm the transfer** — click the confirmation link in the email. Standard `.com`/`.eu`/`.xyz` transfers complete in 5–7 days. `.nl` domains use the SIDN push mechanism (same-day if both registrars use SIDN API).
8. **After transfer** — INWX becomes the registrar and activates its own nameservers. Verify all DNS records are live: `dig MX yourdomain.tld`, `dig TXT yourdomain.tld`.
9. **Raise TTLs** — set records back to `3600` or `86400` once DNS is stable.

> Versio may charge no transfer fee for most TLDs; INWX also charges no inbound transfer fee. Check per-TLD rules at each registrar before initiating.

#### Migrating from ClouDNS (DNS hosting migration)

ClouDNS is a DNS hosting provider (not a registrar) — the domain is still registered at Versio (or wherever). Migration means switching authoritative nameservers:

1. **Export zone from ClouDNS** — ClouDNS dashboard → zone → Export → BIND format. This gives you a `.txt` zone file with all records.
2. **Import / recreate records at INWX DNS** (or Hetzner DNS):
   - INWX: Domains → DNS → Import zone (BIND format supported).
   - Hetzner DNS: DNS console → Import zone file (BIND format).
3. **Double-check every record** — especially MX, SPF (`TXT v=spf1 ...`), DKIM (`TXT` on `selector._domainkey`), DMARC (`TXT` on `_dmarc`), and any A/CNAME for VPS services.
4. **Note the new nameservers** — INWX provides NS like `ns1.inwx.de / ns2.inwx.de`; Hetzner DNS provides `hydrogen.ns.hetzner.com / oxygen.ns.hetzner.com / helium.ns.hetzner.de`.
5. **Lower TTLs at ClouDNS** — set all records to TTL `300` and wait 24 h before the next step.
6. **Change nameservers at Versio** — Versio control panel → domain → nameservers → enter new NS from INWX or Hetzner. Save.
7. **Wait for propagation** — global propagation with TTL 300 takes ~30 min. Check with `dig NS yourdomain.tld @8.8.8.8`.
8. **Verify mail flow** — send a test email to each mailbox, check DKIM signing, check `mail-tester.com` score.
9. **Cancel ClouDNS** — once all domains are propagated and email confirmed, cancel ClouDNS zones/subscription.

---

## Solution A: Infomaniak kSuite + Hetzner VPS

### Design goal

Simplest day-to-day experience for all 5 family members. A single Swiss vendor covers everything the family touches (mail, files, docs, calendar, contacts). The VPS is invisible to the family — it only runs Immich (photos), Vaultwarden (passwords), Infisical (app secrets) and home-grown apps.

### Architecture

```ascii
Family members
    │
    ├── Infomaniak kSuite (Swiss managed)
    │       ├── kMail        — email, webmail, iOS/Android app
    │       ├── kDrive       — file sync, web access, iOS/Android app
    │       ├── OnlyOffice   — Docs / Sheets / Slides (via kDrive)
    │       ├── Calendar     — CalDAV, shared family calendars
    │       └── Contacts     — CardDAV, mobile sync
    │
    └── Hetzner VPS (admin only)
            ├── Immich           — photo management (mobile auto-upload)
            ├── Vaultwarden      — password manager (Bitwarden-compatible)
            ├── Infisical        — app secret management
            ├── Home-grown apps  — Docker / k3s
            └── Nginx / Caddy    — reverse proxy + TLS (Let's Encrypt)

DNS (registrar)
    ├── primary domain  → kSuite MX + SPF/DKIM/DMARC
    └── alias domains   → kSuite MX (forwarding to primary mailboxes)
```

### Components

| Layer                | Service                          | Provider                     | Notes                                                                                                                                   |
| -------------------- | -------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Email                | kSuite Mail                      | Infomaniak (CH 🇨🇭)            | 5 mailboxes, custom domains, alias domains, forwarding, webmail, CalDAV/CardDAV, ActiveSync. SPF/DKIM/DMARC managed.                    |
| Calendar             | kSuite Calendar                  | Infomaniak (CH 🇨🇭)            | Shared family calendars, delegation, CalDAV, iOS/Android sync.                                                                          |
| Contacts             | kSuite Contacts                  | Infomaniak (CH 🇨🇭)            | CardDAV, vCard import/export, mobile sync.                                                                                              |
| Files                | kDrive                           | Infomaniak (CH 🇨🇭)            | 3–6 TB shared storage, desktop + mobile apps, web access, versioning.                                                                   |
| Docs / Office        | OnlyOffice (via kDrive)          | Infomaniak (CH 🇨🇭)            | Docs/Sheets/Slides in browser; no simultaneous editing required.                                                                        |
| Photos               | Immich                           | Hetzner VPS (DE 🇩🇪)           | Google Photos replacement; timeline, face recognition, shared albums, mobile auto-upload app.                                           |
| Passwords            | Vaultwarden                      | Hetzner VPS (DE 🇩🇪)           | Self-hosted Bitwarden server; family uses existing Bitwarden Firefox extension + iPhone app unchanged.                                  |
| App secrets & config | Infisical                        | Hetzner VPS (DE 🇩🇪)           | Per-app / per-env secrets **and** key-value app config; CLI + SDK for home-grown apps and CI/CD; replaces Azure App Config / Consul KV. |
| Identity (SSO)       | **Authentik** (or Keycloak)      | Hetzner VPS (DE 🇩🇪)           | OIDC/OAuth2 SSO for Immich, Infisical, Vaultwarden and home-grown apps; 2FA enforcement; user lifecycle management.                     |
| Compute / apps       | Docker on Hetzner                | Hetzner VPS (DE 🇩🇪)           | Home-grown apps, Immich, Vaultwarden, Infisical run as Docker Compose services.                                                         |
| Reverse proxy        | Caddy                            | Hetzner VPS (DE 🇩🇪)           | Automatic TLS (Let's Encrypt), subdomain routing for all VPS services.                                                                  |
| Backups              | BorgBackup → Hetzner Storage Box | Hetzner (DE 🇩🇪)               | Encrypted daily backups of VPS data (Vaultwarden, Immich, Infisical, app DBs). kDrive has built-in 30-day versioning.                   |
| DNS                  | **INWX** (or Hetzner DNS)        | INWX (DE 🇩🇪) / Hetzner (DE 🇩🇪) | MX, SPF, DKIM, DMARC, A/CNAME for VPS services per domain. INWX for registration + DNS; delegate to Hetzner DNS if preferred.           |

### Domain & email setup

```
primary:   huybrechts.xyz   → kSuite MX → 5 mailboxes
alias 1:   domain2.tld      → kSuite MX → alias → primary mailboxes
alias 2:   domain3.tld      → kSuite MX → alias → primary mailboxes
alias 3:   domain4.tld      → forward at DNS level or kSuite alias domain
alias 4:   domain5.tld      → forward at DNS level or kSuite alias domain
```

Each domain gets its own SPF, DKIM (key generated by kSuite), and DMARC record.

### VPS sizing

| Spec        | Value                                                          |
| ----------- | -------------------------------------------------------------- |
| Model       | Hetzner CPX31                                                  |
| vCPU        | 4                                                              |
| RAM         | 8 GB                                                           |
| SSD         | 160 GB (OS + apps + Vaultwarden + Infisical + Immich thumbs)   |
| Network     | 20 TB/mo                                                       |
| Cost        | ~€15/mo                                                        |
| Storage Box | Hetzner BX11 (1 TB) for Immich originals + BorgBackup → ~€4/mo |

> Scale up to CPX41 (8 vCPU / 16 GB) or BX40 (5 TB) if home-grown apps demand more resources.

### Security & privacy

- kSuite: Swiss nFADP + GDPR, DPA available, TLS in transit, encrypted at rest, DKIM/DMARC managed.
- VPS: UFW firewall (only ports 80/443/SSH), SSH key-only login, Fail2Ban, automatic security updates (unattended-upgrades).
- Caddy: automatic HTTPS, HSTS, modern TLS 1.2/1.3 only.
- Authentik: enforce 2FA (TOTP/WebAuthn) for all users; use as OIDC provider for Immich, Infisical, Vaultwarden and home-grown apps; daily encrypted backup of Authentik DB.
- Vaultwarden: HTTPS only, 2FA via Authentik OIDC, admin token protected, daily encrypted backup.
- Immich: OIDC login via Authentik; private, not internet-exposed without auth.
- Infisical: internal-only or Tailscale-gated; secrets never stored in env files or git.

### Monthly cost estimate (5 users)

| Item                                        | Cost                                                                |
| ------------------------------------------- | ------------------------------------------------------------------- |
| Infomaniak kSuite (5 users, kDrive 3 TB)    | ~€25-35/mo                                                          |
| Infomaniak kDrive extra storage (to ~5 TB)  | ~€5-10/mo                                                           |
| Hetzner CPX31 VPS                           | €15/mo                                                              |
| Hetzner BX11 Storage Box (Immich + backups) | ~€4/mo                                                              |
| Domains (5, keep existing)                  | ~€5-8/mo                                                            |
| Vaultwarden                                 | €0 (on VPS)                                                         |
| Infisical                                   | €0 (on VPS, open source)                                            |
| Immich                                      | €0 (on VPS, open source)                                            |
| **Total**                                   | **~€54-72/mo**                                                      |
| **vs current spend**                        | ~€58-81/mo — similar cost, 2 extra users, Swiss privacy, no MTA ops |

### Pros

- Simplest experience for non-tech family: one login, one app ecosystem (kMail/kDrive), works on iOS/Android without configuration.
- Admin only manages 1 VPS for non-email services.
- Swiss privacy for all email/files/docs/calendar; German privacy for VPS workloads.
- No CalDAV/CardDAV configuration needed for family — kSuite handles it natively.
- Zero UX change for passwords (same Bitwarden app).
- kSuite has a DPA and complies with Swiss nFADP + GDPR.

### Cons

- Infomaniak vendor dependency for core collaboration (mail, drive, calendar).
- kDrive is not as feature-rich as Nextcloud for power-user workflows.
- No built-in E2E encryption for email (PGP optional but not automatic).
- VPS still needs admin attention for updates, monitoring and backups.

---

## Solution B — Proton + Hetzner VPS

### Design goal

Maximum privacy and encryption. Proton provides zero-access encrypted email, calendar and contacts. The VPS covers files, photos, passwords, secrets and home-grown apps. Best for users who prioritise E2E encryption above convenience.

### Architecture

```
Family members
    │
    ├── Proton (Swiss managed, zero-access E2E)
    │       ├── Proton Mail     — email, webmail, iOS/Android app (+ Bridge for IMAP clients)
    │       ├── Proton Calendar — encrypted calendar, iOS/Android app
    │       ├── Proton Contacts — encrypted contacts
    │       └── Proton VPN      — included in Family plan
    │
    └── Hetzner VPS (admin only)
            ├── Nextcloud        — file sync, web/mobile access, shared drives
            ├── OnlyOffice Docs  — document editing (integrated with Nextcloud)
            ├── Immich           — photo management
            ├── Vaultwarden      — password manager
            ├── Infisical        — app secret management
            ├── Home-grown apps  — Docker / k3s
            └── Caddy            — reverse proxy + TLS

DNS (registrar)
    ├── primary domain  → Proton MX + SPF/DKIM/DMARC
    └── alias domains   → Proton MX or registrar-level forward
```

### Components

| Layer                | Service                          | Provider                     | Notes                                                                                                                                                                        |
| -------------------- | -------------------------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Email                | Proton Mail (Family plan)        | Proton (CH 🇨🇭)                | Zero-access E2E encrypted; 5 mailboxes + 1 spare; custom domains + alias domains; Proton Bridge for IMAP clients (Outlook, Thunderbird, Apple Mail). SPF/DKIM/DMARC managed. |
| Calendar             | Proton Calendar                  | Proton (CH 🇨🇭)                | E2E encrypted; iOS/Android app. **Note: no CalDAV export** — calendar is Proton-app-only.                                                                                    |
| Contacts             | Proton Contacts                  | Proton (CH 🇨🇭)                | E2E encrypted; iOS/Android app. **Note: no CardDAV** — contacts are Proton-app-only.                                                                                         |
| VPN                  | Proton VPN (included)            | Proton (CH 🇨🇭)                | All 10 devices (Family plan); network privacy for all family members.                                                                                                        |
| Files                | Nextcloud                        | Hetzner VPS (DE 🇩🇪)           | 5 TB+ via Hetzner Storage Box; web + desktop + iOS/Android app; shared folders; versioning.                                                                                  |
| Docs / Office        | OnlyOffice Docs (Docker)         | Hetzner VPS (DE 🇩🇪)           | Integrated with Nextcloud; Docs/Sheets/Slides in browser.                                                                                                                    |
| Photos               | Immich                           | Hetzner VPS (DE 🇩🇪)           | Google Photos replacement; timeline, face recognition, shared albums, mobile auto-upload.                                                                                    |
| Passwords            | Vaultwarden                      | Hetzner VPS (DE 🇩🇪)           | Self-hosted Bitwarden server; family uses Bitwarden Firefox extension + iPhone app.                                                                                          |
| App secrets & config | Infisical                        | Hetzner VPS (DE 🇩🇪)           | Per-app / per-env secrets **and** key-value app config; CLI + SDK; replaces Azure App Config / Consul KV.                                                                    |
| Compute / apps       | Docker on Hetzner                | Hetzner VPS (DE 🇩🇪)           | Nextcloud, OnlyOffice, Immich, Vaultwarden, Infisical, home-grown apps.                                                                                                      |
| Reverse proxy        | Caddy                            | Hetzner VPS (DE 🇩🇪)           | Automatic TLS, subdomain routing.                                                                                                                                            |
| Backups              | BorgBackup → Hetzner Storage Box | Hetzner (DE 🇩🇪)               | Encrypted daily backups of all VPS data (Nextcloud, Immich, Vaultwarden, Infisical, DBs).                                                                                    |
| DNS                  | **INWX** (or Hetzner DNS)        | INWX (DE 🇩🇪) / Hetzner (DE 🇩🇪) | Per-domain MX, SPF, DKIM, DMARC. Proton generates DKIM keys per custom domain in its admin panel.                                                                            |

### Domain & email setup

```
primary:   huybrechts.xyz   → Proton MX → 5 mailboxes
alias 1:   domain2.tld      → Proton custom domain → alias addresses
alias 2:   domain3.tld      → Proton custom domain → alias addresses
alias 3:   domain4.tld      → registrar MX forward → primary Proton mailbox
alias 4:   domain5.tld      → registrar MX forward → primary Proton mailbox
```

> Proton Family supports up to 3 custom domains on the Family plan. Additional domains may need forwarding at registrar level or an upgrade.

### Important constraint: no standard CalDAV/CardDAV

Proton Calendar and Contacts do **not** expose CalDAV/CardDAV. This means:

- Family members must use the Proton Calendar app on iOS/Android (not Apple Calendar, Google Calendar, etc.).
- Contacts must be managed in the Proton Contacts app, not the system address book.
- This is a real UX trade-off for non-tech users — they need to adopt new apps.

Mitigation: Nextcloud on the VPS can run its own Calendar + Contacts (CalDAV/CardDAV) alongside Proton for users who need standard protocol access. This adds complexity but gives the best of both worlds.

### VPS sizing

| Spec        | Value                                                          |
| ----------- | -------------------------------------------------------------- |
| Model       | Hetzner CPX41                                                  |
| vCPU        | 8                                                              |
| RAM         | 16 GB                                                          |
| SSD         | 240 GB                                                         |
| Cost        | ~€26/mo                                                        |
| Storage Box | Hetzner BX40 (5 TB) for Nextcloud + Immich + backups → ~€16/mo |

> CPX41 recommended over CPX31 because Nextcloud + OnlyOffice + Immich + Vaultwarden + Infisical is a heavier stack than Solution A.

### Security & privacy

- Proton: Swiss law, zero-access encryption for email/calendar/contacts, no metadata logging, independent security audits, strong DPA.
- Proton VPN: included in Family plan, all 10 devices, no-logs policy, audited.
- Proton Bridge: enables standard IMAP/SMTP clients while maintaining E2E encryption locally.
- VPS: same hardening as Solution A (UFW, SSH keys, Fail2Ban, Caddy HTTPS, unattended-upgrades).
- Nextcloud: admin-managed, encrypted at rest via storage encryption app (optional), TLS in transit.
- Vaultwarden + Infisical: same as Solution A.

### Monthly cost estimate (5 users)

| Item                                            | Cost                                                 |
| ----------------------------------------------- | ---------------------------------------------------- |
| Proton Family plan (6 users, 3 TB Proton Drive) | ~€30/mo                                              |
| Hetzner CPX41 VPS                               | ~€26/mo                                              |
| Hetzner BX40 Storage Box (5 TB)                 | ~€16/mo                                              |
| Domains (5, keep existing)                      | ~€5-8/mo                                             |
| Vaultwarden                                     | €0 (on VPS)                                          |
| Infisical                                       | €0 (on VPS)                                          |
| Immich                                          | €0 (on VPS)                                          |
| Nextcloud + OnlyOffice                          | €0 (on VPS, open source)                             |
| **Total**                                       | **~€77-80/mo**                                       |
| **vs current spend**                            | ~€58-81/mo — slight premium for E2E encryption + VPN |

### Pros

- Strongest email/calendar/contacts privacy: zero-access E2E encryption, Swiss law, audited.
- VPN included for all 10 family devices — no separate VPN subscription needed.
- Full control over files, photos, passwords and secrets on EU VPS.
- Proton mobile apps are polished and easy for non-tech users (for mail/calendar/contacts).
- OpenBao or Infisical for secrets — no IBM/HashiCorp licence concern.

### Cons

- No standard CalDAV/CardDAV for calendar/contacts — family must use Proton apps only.
- Proton Drive is paid storage that overlaps with Nextcloud on VPS — paying for two storage layers.
- Proton Bridge needed for IMAP clients (Outlook, Thunderbird, Apple Mail) — extra step for non-tech users.
- Heavier VPS stack (Nextcloud + OnlyOffice + Immich + Vaultwarden + Infisical) requires more admin effort.
- Most expensive of the three options.

---

## Solution C — Fully self-hosted + managed email (Mailbox.org + Hetzner VPS)

### Design goal

Maximum control and lowest recurring cost. Managed email only (Mailbox.org, German privacy). Everything else — files, docs, photos, calendar, contacts, passwords, secrets — runs on a single Hetzner VPS. Uses standard open protocols (IMAP/CalDAV/CardDAV) so any client app works without configuration.

### Architecture

```
Family members
    │
    ├── Mailbox.org (managed email, DE)
    │       └── 5 mailboxes, webmail, CalDAV/CardDAV, custom domains, PGP
    │
    └── Hetzner VPS (admin manages everything else)
            ├── Nextcloud Hub    — files, calendar, contacts, tasks, notes, sharing
            ├── OnlyOffice Docs  — document editing (integrated with Nextcloud)
            ├── Immich           — photo management
            ├── Vaultwarden      — password manager
            ├── Infisical        — app secret management
            ├── Home-grown apps  — Docker / k3s
            └── Caddy            — reverse proxy + TLS

DNS (registrar)
    ├── primary domain  → Mailbox.org MX + SPF/DKIM/DMARC
    └── alias domains   → Mailbox.org MX or alias domain config
```

### Components

| Layer                | Service                          | Provider                     | Notes                                                                                                                                    |
| -------------------- | -------------------------------- | ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Email                | Mailbox.org Business             | Mailbox.org (DE 🇩🇪)           | 5× Business Lite (~€3/user/mo); custom domains; alias domains; PGP built-in; CalDAV/CardDAV; IMAP/SMTP; webmail. SPF/DKIM/DMARC managed. |
| Calendar             | Nextcloud Calendar               | Hetzner VPS (DE 🇩🇪)           | CalDAV, shared family calendars, iOS/Android sync via any CalDAV-compatible app (Apple Calendar, Thunderbird, etc.).                     |
| Contacts             | Nextcloud Contacts               | Hetzner VPS (DE 🇩🇪)           | CardDAV, system address book sync on iOS/Android, vCard import/export.                                                                   |
| Files                | Nextcloud Files                  | Hetzner VPS (DE 🇩🇪)           | 5 TB+ via Hetzner Storage Box; web + desktop + iOS/Android app; shared folders; Group Folders for family; versioning.                    |
| Docs / Office        | OnlyOffice Docs (Docker)         | Hetzner VPS (DE 🇩🇪)           | Integrated with Nextcloud for in-browser editing of Docs/Sheets/Slides.                                                                  |
| Photos               | Immich                           | Hetzner VPS (DE 🇩🇪)           | Google Photos replacement; timeline, face recognition, shared albums, mobile auto-upload.                                                |
| Passwords            | Vaultwarden                      | Hetzner VPS (DE 🇩🇪)           | Self-hosted Bitwarden server; family uses Bitwarden Firefox extension + iPhone app.                                                      |
| App secrets & config | Infisical                        | Hetzner VPS (DE 🇩🇪)           | Per-app / per-env secrets **and** key-value app config; CLI + SDK; replaces Azure App Config / Consul KV.                                | } |
| Compute / apps       | Docker on Hetzner                | Hetzner VPS (DE 🇩🇪)           | Nextcloud, OnlyOffice, Immich, Vaultwarden, Infisical, home-grown apps as Docker Compose services.                                       |
| Reverse proxy        | Caddy                            | Hetzner VPS (DE 🇩🇪)           | Automatic TLS, subdomain routing for all services.                                                                                       |
| Backups              | BorgBackup → Hetzner Storage Box | Hetzner (DE 🇩🇪)               | Encrypted daily backups: Nextcloud data + DB, Immich, Vaultwarden, Infisical, app DBs. Mailbox.org mail backed up by provider.           |
| DNS                  | **INWX** (or Hetzner DNS)        | INWX (DE 🇩🇪) / Hetzner (DE 🇩🇪) | Per-domain MX, SPF, DKIM (from Mailbox.org admin panel), DMARC.                                                                          |

### Domain & email setup

```
primary:   huybrechts.xyz   → Mailbox.org MX → 5 mailboxes
alias 1:   domain2.tld      → Mailbox.org alias domain → primary mailboxes
alias 2:   domain3.tld      → Mailbox.org alias domain → primary mailboxes
alias 3:   domain4.tld      → Mailbox.org alias domain or registrar forward
alias 4:   domain5.tld      → Mailbox.org alias domain or registrar forward
```

Mailbox.org Business supports multiple custom domains. DKIM keys generated per domain in the Mailbox.org admin panel.

### VPS sizing

| Spec        | Value                         |
| ----------- | ----------------------------- |
| Model       | Hetzner CPX41                 |
| vCPU        | 8                             |
| RAM         | 16 GB                         |
| SSD         | 240 GB                        |
| Cost        | ~€26/mo                       |
| Storage Box | Hetzner BX40 (5 TB) → ~€16/mo |

> CPX41 needed for Nextcloud + OnlyOffice + Immich + Vaultwarden + Infisical stack. Consider a separate CPX21 for home-grown apps if resource contention is a concern.

### Security & privacy

- Mailbox.org: German BDSG + GDPR, PGP built-in, TLS in transit, ISO 27001 certified, DPA available, no US jurisdiction.
- Nextcloud: admin-controlled, TLS via Caddy, optional server-side encryption (at-rest), LDAP/OIDC possible, 2FA via TOTP or WebAuthn.
- CalDAV/CardDAV: standard protocols over TLS — works with Apple Calendar, Thunderbird, Android natively.
- VPS: UFW, SSH keys only, Fail2Ban, Caddy HTTPS, unattended-upgrades.
- Vaultwarden: HTTPS, 2FA enforced, daily encrypted backup.
- Infisical: internal-only or Tailscale-gated.

### Monthly cost estimate (5 users)

| Item                             | Cost                                                            |
| -------------------------------- | --------------------------------------------------------------- |
| Mailbox.org Business (5 × €3/mo) | €15/mo                                                          |
| Hetzner CPX41 VPS                | ~€26/mo                                                         |
| Hetzner BX40 Storage Box (5 TB)  | ~€16/mo                                                         |
| Domains (5, keep existing)       | ~€5-8/mo                                                        |
| Nextcloud + OnlyOffice           | €0 (open source)                                                |
| Vaultwarden                      | €0 (on VPS)                                                     |
| Infisical                        | €0 (on VPS)                                                     |
| Immich                           | €0 (on VPS)                                                     |
| **Total**                        | **~€62-65/mo**                                                  |
| **vs current spend**             | ~€58-81/mo — similar or lower, all EU, no MTA ops, full control |

### Pros

- Lowest vendor lock-in: all services use open protocols (IMAP, CalDAV, CardDAV, WebDAV).
- Calendar and contacts work with any standard client (Apple Calendar, Thunderbird, Android) — no app to install.
- Cheapest recurring cost of the three solutions.
- Full data control: all non-email data on your own VPS in Germany.
- Mailbox.org is German, GDPR-compliant, DPA available, PGP integrated.
- Nextcloud is a mature, well-maintained platform with a large ecosystem.

### Cons

- Heaviest admin burden: Nextcloud, OnlyOffice, Immich, Vaultwarden, Infisical all need updates, monitoring and backups.
- Nextcloud UX is functional but less polished than kSuite or Proton apps for non-tech users.
- Family members need to set up CalDAV/CardDAV sync manually (one-time, but requires guided setup).
- No built-in VPN (add Tailscale or WireGuard on VPS if needed, free).

---

## Comparison

| Criterion             |  Solution A (kSuite)  |      Solution B (Proton)       |    Solution C (Mailbox.org)    |
| --------------------- | :-------------------: | :----------------------------: | :----------------------------: |
| **Email privacy**     | ★★★★☆ Swiss, TLS+rest |  ★★★★★ Swiss, zero-access E2E  |     ★★★★☆ German, TLS+PGP      |
| **Calendar/Contacts** |  ★★★★★ native CalDAV  |     ★★☆☆☆ Proton apps only     |     ★★★★★ standard CalDAV      |
| **File storage**      | ★★★★☆ kDrive managed  |  ★★★★★ Nextcloud self-hosted   |  ★★★★★ Nextcloud self-hosted   |
| **Family UX**         |  ★★★★★ one app, easy  |  ★★★★☆ Proton apps, polished   |    ★★★☆☆ needs CalDAV setup    |
| **Admin overhead**    |   ★★★★☆ low (1 VPS)   | ★★★☆☆ medium (heavy VPS stack) | ★★★☆☆ medium (heavy VPS stack) |
| **Cost /mo**          |        ~€54-72        |            ~€77-80             |            ~€62-65             |
| **VPN included**      |           ✗           |          ✓ Proton VPN          |     ✗ (add Tailscale free)     |
| **Vendor lock-in**    |  Medium (Infomaniak)  |      Medium (Proton apps)      |      Low (open protocols)      |
| **Password manager**  |   Vaultwarden (VPS)   |       Vaultwarden (VPS)        |       Vaultwarden (VPS)        |
| **Secret manager**    |    Infisical (VPS)    |        Infisical (VPS)         |        Infisical (VPS)         |

---

## Secret manager decision table

| Tool                                      | Licence    | Self-hosted        | IBM/HashiCorp risk                       | When to use                                                        |
| ----------------------------------------- | ---------- | ------------------ | ---------------------------------------- | ------------------------------------------------------------------ |
| **Infisical** ⭐                           | MIT        | ✓ Docker Compose   | None                                     | Recommended; modern UI, per-app/env secrets, CLI/SDK, audit log    |
| **OpenBao**                               | MPL 2.0    | ✓                  | None (fork of Vault, not IBM-controlled) | If you need Vault-style dynamic credentials or fine-grained ACL    |
| **Bitwarden CLI → Vaultwarden**           | AGPL       | ✓ (already on VPS) | None                                     | Good starting point; free; use until app count demands namespacing |
| **HashiCorp Vault**                       | BSL        | ✓                  | ⚠ IBM-owned, non-OSS licence             | Not recommended; use OpenBao instead if Vault features needed      |
| **Azure Key Vault / AWS Secrets Manager** | Commercial | ✗ (cloud only)     | Vendor cloud                             | Not applicable for EU self-hosted privacy-first setup              |

**Recommendation:** start with Bitwarden CLI → Vaultwarden (zero cost, already deployed). Add Infisical when you have multiple apps needing isolated secret environments. Keep OpenBao as a fallback if dynamic DB credentials or deep audit trails become a requirement.

---

*Next step: choose a solution and create a migration plan (Google Takeout export, IMAP sync, CalDAV/vCard import, domain DNS cutover checklist).*
