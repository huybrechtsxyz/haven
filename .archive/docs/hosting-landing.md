# Family Landing Page — Analysis & Design

> Should Haven have a dashboard/portal? If so, which one, and how does it wire in?

**Status:** Analysis — pending Vincent's decisions on open questions  
**Date:** 2026-06-08  
**Author:** Mal (Lead Architect)

---

## Problem Statement

Haven currently has 6 services, each at its own subdomain. Family members need to bookmark them individually, and there is no visibility control — everyone who can reach a subdomain can reach the service, regardless of whether it is relevant to them.

Specific problems this causes now, and increasingly as the platform grows:

- **No per-user filtering.** Portainer and WUD are admin tools. Kids do not need to see them.
- **No shared entry point.** Each person needs their own bookmark set.
- **No quick links to external sites.** Family members want links to their school portals, streaming services, etc. alongside Haven services.
- **Discoverability is poor.** New services added to Hearth are invisible until communicated manually.

A family landing page / dashboard addresses all of these — one URL, login once, see your apps.

---

## Options Compared

| Option | Auth integration | Per-user app visibility | Widgets | Complexity | Fit for Haven |
|---|---|---|---|---|---|
| **Authentik Application Portal** | Native — it _is_ Authentik | Yes — controlled by policy bindings | None | Zero (already deployed) | Good baseline; limited UX |
| **Homarr** | OIDC (including Authentik) | Yes — group-based visibility via OIDC claims | Yes — service status, calendar, weather, RSS, search | Low–Medium | **Best fit** |
| **Homepage** | None (YAML only) | No — same config for everyone | Yes — rich integrations | Low | Poor — no per-user visibility |
| **Glance** | None | No | Yes — RSS, weather, bookmarks, Hacker News, GitHub | Very low | Poor — personal, not family-multi-user |
| **Heimdall** | None natively; basic reverse proxy auth possible | No | Minimal | Very low | Poor — no per-user control |

**Notes:**

- **Authentik Application Portal** (`auth.huybrechts.xyz/if/user/`) is the built-in app launcher already available to all users. It respects policy bindings exactly — users only see apps they are authorised to access. It is plain and functional, not widget-rich. Worth knowing it exists regardless of what else is chosen.
- **Homarr** v0.15+ supports OIDC login and exposes per-group app board visibility. It is actively maintained and has a Docker-first deployment model. The widget set (service status, search, calendar, weather) is useful for a family context.
- **Homepage** is popular but fundamentally static — one YAML config, same view for all users. Not a fit when the requirement is per-user filtering.
- **Glance** is a personal feed aggregator, not a multi-user portal. Single user or single-view only.
- **Heimdall** predates OIDC dashboards and has no meaningful auth integration.

---

## Recommendation

**Run Authentik Application Portal as the immediate zero-cost solution, then add Homarr when widget value justifies the extra service.**

Rationale:

1. The Authentik portal is already live and already respects group policy bindings. It requires no new infrastructure. Configuring it properly (ensuring every app has a correct launch URL and icon) costs an hour, not a sprint. For the current 6-service stack this may be sufficient.

2. Homarr is the right longer-term choice when the service count grows further and family members want a richer entry point (weather, news, quick search, status at a glance). Its OIDC integration with Authentik is well-documented and follows the same wiring pattern already established for Vaultwarden and Infisical.

3. Do not use Homepage or Glance — neither supports per-user visibility, which is the core requirement.

**Decision point:** If the Authentik portal UX (plain list of tiles) is acceptable to the family, defer Homarr. If a richer dashboard with widgets is desired now, implement Homarr immediately. The two can coexist.

---

## Homarr Integration Design

### Docker Compose service

```yaml
homarr:
  image: ghcr.io/ajnart/homarr:latest
  container_name: haven-homarr
  restart: unless-stopped
  volumes:
    - /opt/haven/etc/homarr/configs:/app/data/configs
    - /opt/haven/var/data/homarr/icons:/app/public/icons
    - /var/run/docker.sock:/var/run/docker.sock:ro   # optional — enables auto-discovery
  environment:
    - AUTH_PROVIDER=oidc
    - AUTH_OIDC_URI=https://auth.huybrechts.xyz/application/o/homarr/
    - AUTH_OIDC_CLIENT_ID=homarr
    - AUTH_OIDC_CLIENT_SECRET=${HOMARR_SSO_CLIENT_SECRET}
    - AUTH_OIDC_CLIENT_NAME=Haven SSO
    - AUTH_OIDC_ADMIN_GROUP=admins
    - BASE_URL=https://home.huybrechts.xyz
  networks:
    - haven
```

> The Docker socket mount is optional. It allows Homarr to auto-discover running containers and pull their status. If it makes you uncomfortable, omit it — boards can be configured manually.

### Authentik OIDC wiring

In `deploy/ansible-config/templates/authentik-blueprint.yaml.j2`, add:

**Provider:**

```yaml
- model: authentik_providers_oauth2.oauth2provider
  state: present
  identifiers:
    name: homarr
  attrs:
    name: homarr
    client_type: confidential
    client_id: homarr
    client_secret: "{{ homarr_sso_client_secret }}"
    redirect_uris: "https://home.huybrechts.xyz/api/auth/callback/oidc"
    signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]
    authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
    property_mappings:
      - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
      - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
      - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
      - !Find [authentik_providers_oauth2.scopemapping, [scope_name, groups]]
```

**Application:**

```yaml
- model: authentik_core.application
  state: present
  identifiers:
    slug: homarr
  attrs:
    name: Home
    slug: homarr
    provider: !Find [authentik_providers_oauth2.oauth2provider, [name, homarr]]
    meta_launch_url: https://home.huybrechts.xyz
    meta_icon: https://home.huybrechts.xyz/favicon.png
    policy_engine_mode: any
```

**Policy bindings** — bind the `members` group (everyone) so all family users can access the dashboard:

```yaml
- model: authentik_policies.policybinding
  state: present
  identifiers:
    target: !Find [authentik_core.application, [slug, homarr]]
    order: 0
  attrs:
    group: !Find [authentik_core.group, [name, members]]
    enabled: true
```

The `groups` scope mapping is important — Homarr reads the `groups` claim from the OIDC token to determine which board visibility group the user belongs to.

### Caddy reverse proxy entry

In `services/hearth/caddy/Caddyfile`:

```caddyfile
home.huybrechts.xyz {
    reverse_proxy haven-homarr:7575
}
```

No forward-auth needed — Homarr handles authentication internally via its OIDC flow.

### strata module

`config/hearth/modules/mod-homarr.yaml`:

```yaml
apiVersion: strata.huybrechts.xyz/v1
kind: module
meta:
  name: homarr
  annotations:
    description: Homarr family dashboard — OIDC-authenticated per-user app launcher with widgets
  labels:
    version: "1.0.0"
  tags: [haven, hearth, homarr, dashboard, landing]
spec:
  source:
    repository: haven
    source_path: services/hearth/homarr
  type: compose
  references:
    secrets:
      - HOMARR_SSO_CLIENT_SECRET
  services:
    - name: homarr
      image: ghcr.io/ajnart/homarr:latest
      restart: unless-stopped
      environment:
        - key: AUTH_PROVIDER
          value: oidc
        - key: AUTH_OIDC_URI
          value: https://auth.huybrechts.xyz/application/o/homarr/
        - key: AUTH_OIDC_CLIENT_ID
          value: homarr
        - key: AUTH_OIDC_CLIENT_SECRET
          secret: HOMARR_SSO_CLIENT_SECRET
        - key: AUTH_OIDC_CLIENT_NAME
          value: Haven SSO
        - key: AUTH_OIDC_ADMIN_GROUP
          value: admins
        - key: BASE_URL
          value: https://home.huybrechts.xyz
      mounts:
        - name: configs
          type: bind
          source_path: /opt/haven/etc/homarr/configs
          target_path: /app/data/configs
        - name: icons
          type: bind
          source_path: /opt/haven/var/data/homarr/icons
          target_path: /app/public/icons
```

### Secrets required

| Secret | Where generated | Notes |
|---|---|---|
| `HOMARR_SSO_CLIENT_SECRET` | `python -c "from secrets import token_urlsafe; print(token_urlsafe(48))"` | Add to GitHub repo secrets + blueprint template vars + deploy `.env` |

Follow the same three-place wiring established for other SSO-enabled services:
1. GitHub repo secret → `production` environment
2. `deploy.yml` config vars block → passed to Ansible blueprint template
3. `deploy.yml` deploy vars block + `.env` template in `hearth-deploy.yml` → injected into container at runtime

### Per-user / per-group app visibility in Homarr

Homarr boards work as follows:

- A **board** is a named layout (tiles, widgets, arrangement).
- Boards can be set to **public**, **private**, or **group-restricted**.
- With OIDC enabled, Homarr maps OIDC group claims to its internal user groups.
- The `AUTH_OIDC_ADMIN_GROUP` env var designates which OIDC group gets Homarr admin rights.

**Recommended board structure for Haven:**

| Board | Visibility | Contents |
|---|---|---|
| `Family` | All authenticated users (`members` group) | Shared services: Vaultwarden; external links (school portals, streaming, etc.) |
| `Admin` | `admins` group only | Portainer, WUD, Infisical, Authentik admin |
| `Parents` | `parents` group | Everything in Family + adult-only links |

The per-person personalisation (Vincent's websites, each child's school portal) can either live on a personal private board each user configures themselves, or be set up by the admin using named user-boards.

> **Important:** Homarr's group-based board visibility requires that the `groups` claim is included in the OIDC token. This is why the `groups` scope mapping must be added to the Authentik provider definition above.

---

## Open Questions

These need Vincent's decision before implementation starts.

| # | Question | Options | Notes |
|---|---|---|---|
| 1 | **Subdomain** | `home.huybrechts.xyz` or `dashboard.huybrechts.xyz` or `start.huybrechts.xyz` | Pick something short that family will remember. `home.` is intuitive. |
| 2 | **Deploy now or after Authentik portal evaluation?** | Deploy Homarr now / Try Authentik portal first | The Authentik portal takes an hour to configure and is already live. Try it first if the family UX bar is low. |
| 3 | **Docker socket mount** | Enable (auto-discover containers + status) / Disable (manual config only) | Enabling gives automatic service status tiles. Disabling is safer — no container with access to the Docker daemon. |
| 4 | **Board layout per family member** | Admin-managed per-user boards / Let each user manage their own private board | Admin-managed is more work upfront but ensures a consistent experience. |
| 5 | **App list per group** | Which apps does each group see? | Need to decide: do kids see Vaultwarden? Does Infisical appear for parents? Drives the policy binding design. |
| 6 | **Replace or supplement Authentik portal?** | Keep Authentik portal as backup / Make Homarr the primary and remove portal from nav | Can coexist. Homarr can even embed a link to the Authentik portal for self-service (MFA, password reset). |
| 7 | **Homarr image tag pinning** | `latest` / specific semver tag | Recommend pinning to a specific version (consistent with how Authentik is pinned) — check Homarr releases for current stable. |

---

## Next Steps

When Vincent has answered the open questions above, implementation involves:

- [ ] Generate `HOMARR_SSO_CLIENT_SECRET` and store in Vaultwarden
- [ ] Add secret to GitHub repo secrets (`production` environment)
- [ ] Add OIDC provider + application + policy bindings to `authentik-blueprint.yaml.j2`
- [ ] Add Homarr to `authentik-blueprint.yaml.j2` config vars (secret passthrough)
- [ ] Add `config/hearth/modules/mod-homarr.yaml`
- [ ] Add Caddy entry to `services/hearth/caddy/Caddyfile`
- [ ] Add secret to `deploy.yml` deploy vars block and `.env` template in `hearth-deploy.yml`
- [ ] Create `services/hearth/homarr/` directory (Compose file or module source)
- [ ] Deploy and configure boards (Family, Admin, Parents) in Homarr UI
- [ ] Update `docs/GUIDE.md` secrets table
- [ ] Update `docs/AUTHENTIK.md` access control table
- [ ] Announce new URL to family
