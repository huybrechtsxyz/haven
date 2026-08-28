# Jellyfin

> Jellyfin — media streaming server, self-hosted on Forge (k3s).

## Overview

Jellyfin runs on **Forge** (Hetzner CPX41, k3s), in its own `media` Kubernetes namespace — separate from Immich's `immich` namespace and any future self-hosted-app namespaces, so apps can be added/changed independently without colliding. See [Forge](../guides/forge.md) for the node-level overview.

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once (k3s + Traefik installed, Storage Box NFS mounted at `/mnt/storagebox`), and a DNS A record for `media.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## What gets deployed

| Item      | Value                                                                                                                                              |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chart     | `jellyfin` from the official repo, `https://jellyfin.github.io/jellyfin-helm`                                                                      |
| Version   | `3.2.0` (`image.tag` intentionally left unset — auto-matches the chart's own appVersion)                                                           |
| Namespace | `media` (Kubernetes), module file `config/forge/modules/jellyfin.yaml`                                                                             |
| Ingress   | Traefik (`className: traefik`), host `media.{domain}`, TLS via cert-manager (`letsencrypt-staging` initially, see [Immich's pattern](./immich.md)) |

---

## Storage

| Volume               | Type                                | Notes                                                                                                                                                                                                                                         |
| -------------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `persistence.config` | PVC, `local-path`, 5Gi              | Jellyfin's own metadata/database — local disk, not backed up to Storage Box yet                                                                                                                                                               |
| `persistence.media`  | `hostPath`, `/mnt/storagebox/media` | The actual media library. Reuses the *same* Storage Box NFS mount `forge-init.yml` already sets up on the host — deliberately **not** a second, independent in-pod NFS mount (avoids duplicate auth/mount overhead for a single-node cluster) |
| `persistence.cache`  | disabled (default)                  | Transcode cache — left disabled; Jellyfin uses software transcoding only (no GPU), so this isn't performance-critical yet                                                                                                                     |

---

## SSO — Authentik OIDC via K0lin/jellyfin-plugin-sso

Jellyfin has no native OIDC support. SSO requires a third-party plugin.

> **Plugin choice note:** the well-known `9p4/jellyfin-plugin-sso` was **archived by its owner on 2026-05-12**. This setup uses **[K0lin/jellyfin-plugin-sso](https://github.com/K0lin/jellyfin-plugin-sso)** instead — an active, transparent continuation of the same code ("forked from the creator's code, with the intention of continuing to maintain it"), same config/API shape, commits as recent as days old.

The Authentik side is **already automated** — `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Jellyfin (client ID `jellyfin`, `members` group policy) every time `deploy-hearth-config.yml` runs, using the `JELLYFIN_SSO_CLIENT_SECRET` Infisical secret. Uses `issuer_mode: per_provider` (not `global`) — `global` mode's issuer claim is just the bare domain, which breaks strict OIDC issuer validation against the app-specific discovery path; this was discovered and fixed on Immich first (see [immich.md](./immich.md#single-sign-on-authentik)), applied here proactively before Jellyfin's SSO is tested for the first time.

The Jellyfin side needs two manual/scripted steps — Jellyfin has no headless bootstrap, so these can't be fully automated yet:

1. **Install the plugin** (one-time, per Jellyfin instance): Dashboard → Plugins → Repositories → add
   ```
   https://raw.githubusercontent.com/k0lin/jellyfin-plugin-sso/manifest-release/manifest.json
   ```
   then Catalog → install **SSO Authentication** → restart Jellyfin.

2. **Register the Authentik provider** — needs a Jellyfin admin API key (Dashboard → API Keys, itself requires the one-time first-run admin setup via the web UI first):
   ```bash
   curl -X POST -H "Content-Type: application/json" \
     -d '{
           "oidEndpoint": "https://auth.huybrechts.xyz/application/o/jellyfin/",
           "oidClientId": "jellyfin",
           "oidSecret": "<JELLYFIN_SSO_CLIENT_SECRET>",
           "enabled": true,
           "enableAuthorization": false
         }' \
     "https://media.huybrechts.xyz/sso/OID/Add/authentik?api_key=<JELLYFIN_API_KEY>"
   ```

See [K0lin/jellyfin-plugin-sso's README](https://github.com/K0lin/jellyfin-plugin-sso) for the login-button snippet to add under Dashboard → General → Branding → Login disclaimer.

---

## Secrets

| Secret                       | Store     | Used by                                                                                         |
| ---------------------------- | --------- | ----------------------------------------------------------------------------------------------- |
| `JELLYFIN_SSO_CLIENT_SECRET` | Infisical | Authentik's Jellyfin OAuth2 provider (automated) + the plugin's `oidSecret` (manual step above) |

---

## Verification checklist

- [ ] `https://media.{domain}` — Jellyfin loads and is reachable from a browser
- [ ] Media library shows content from `/mnt/storagebox/media`
- [ ] SSO plugin installed and Authentik provider registered
- [ ] "Sign in with SSO" login button works end-to-end

---

## Still open

- `media` namespace just activated in `config/stack/workspace.yaml` — not yet confirmed deployed/healthy on the live cluster
- TLS cert not yet confirmed issued (staging first, same as Immich) — switch to `letsencrypt-prod` once `kubectl describe certificate jellyfin-tls -n media` shows `Ready: True`
- SSO plugin install + provider registration are manual/scripted, not yet automated end-to-end
