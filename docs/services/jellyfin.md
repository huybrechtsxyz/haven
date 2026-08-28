# Jellyfin

> Jellyfin — media streaming server, self-hosted on Forge (k3s).

## Overview

Jellyfin runs on **Forge** (Hetzner CPX41, k3s), in its own `media` Kubernetes namespace — separate from Immich's `immich` namespace and any future self-hosted-app namespaces, so apps can be added/changed independently without colliding. See [Forge](../guides/forge.md) for the node-level overview.

**Prerequisites:**
- `deploy-forge-init.yml` (`31 - Forge - Init`) must have run successfully at least once — installs k3s + Traefik, and (with `configure_smb: true`) mounts the Storage Box media library over SMB/CIFS at `/mnt/storagebox` (Hetzner Storage Box subaccounts don't support NFS — see [Forge](../guides/forge.md)).
- The `system` namespace (`cert-manager` + `cert-manager-issuers`) must already be deployed — Jellyfin's ingress relies on its `letsencrypt-staging`/`letsencrypt-prod` `ClusterIssuer`s existing first.
- A DNS A record for `media.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).
- `deploy-forge-config.yml` (`32 - Forge - Config`, LAN routing to Hearth's Authentik) is **not** required for Jellyfin's SSO to work — confirmed 2026-08-28: the plugin's server-side token exchange resolves `auth.{domain}` via public DNS just fine (an extra network hop, not a blocker). It's a networking optimization only, not a hard dependency for this app.

---

## What gets deployed

| Item      | Value                                                                                                                                                                  |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chart     | `jellyfin` from the official repo, `https://jellyfin.github.io/jellyfin-helm`                                                                                          |
| Version   | `3.2.0` (`image.tag` intentionally left unset — auto-matches the chart's own appVersion)                                                                               |
| Namespace | `media` (Kubernetes), module file `config/forge/modules/jellyfin.yaml`                                                                                                 |
| Ingress   | Traefik (`className: traefik`), host `media.{domain}`, TLS via cert-manager (`letsencrypt-prod`, switched from `letsencrypt-staging` 2026-08-28 once verified issuing) |

---

## Deployment process (in order)

1. Confirm prerequisites above are satisfied (Forge init done, `system` namespace's cert-manager deployed, DNS record exists).
2. Ensure `media` is uncommented in `config/stack/workspace.yaml`'s `spec.namespaces` list (and its `hetzner_forge` topology `namespaces:` sub-list, kept in lockstep) — already done.
3. Run **`33 - Forge - Deploy`** (`strata deploy run --scope apps --stage applications_forge`). This deploys the Helm chart, the ingress (TLS via cert-manager), and — after the Helm deploy succeeds — attempts the automated SSO provider registration step (skips silently if `JELLYFIN_API_KEY` isn't set yet).
4. **New hostname TLS pattern**: leave the ingress annotation on `letsencrypt-staging` for the very first deploy of a brand-new hostname, confirm `kubectl describe certificate -n media` shows `Ready: True`, then switch to `letsencrypt-prod` and redeploy (already done for `media.{domain}` — see [What gets deployed](#what-gets-deployed) above).
5. Complete the **one-time manual step** (API key creation, see [SSO](#sso--authentik-oidc-via-k0linjellyfin-plugin-sso) below) — every deploy after that automatically (re-)registers the SSO provider.
6. Verify with the [checklist](#verification-checklist) below.

---

## Storage

| Volume               | Type                                | Notes                                                                                                                                                                                                                                         |
| -------------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `persistence.config` | PVC, `local-path`, 5Gi              | Jellyfin's own metadata/database — local disk, not backed up to Storage Box yet                                                                                                                                                               |
| `persistence.media`  | `hostPath`, `/mnt/storagebox/media` | The actual media library. Reuses the *same* Storage Box SMB/CIFS mount `forge-init.yml` already sets up on the host — deliberately **not** a second, independent in-pod mount (avoids duplicate auth/mount overhead for a single-node cluster)      |
| `persistence.cache`  | disabled (default)                  | Transcode cache — left disabled; Jellyfin uses software transcoding only (no GPU), so this isn't performance-critical yet                                                                                                                     |

---

## SSO — Authentik OIDC via K0lin/jellyfin-plugin-sso

Jellyfin has no native OIDC support. SSO requires a third-party plugin.

> **Plugin choice note:** the well-known `9p4/jellyfin-plugin-sso` was **archived by its owner on 2026-05-12**. This setup uses **[K0lin/jellyfin-plugin-sso](https://github.com/K0lin/jellyfin-plugin-sso)** instead — an active, transparent continuation of the same code ("forked from the creator's code, with the intention of continuing to maintain it"), same config/API shape, commits as recent as days old.

The Authentik side is **fully automated** — `deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2` creates the OAuth2 Provider + Application for Jellyfin (client ID `jellyfin`, `members` group policy) every time `deploy-hearth-config.yml` runs, using the `JELLYFIN_SSO_CLIENT_SECRET` Infisical secret. Uses `issuer_mode: per_provider` (not `global`) — `global` mode's issuer claim is just the bare domain, which breaks strict OIDC issuer validation against the app-specific discovery path; this was discovered and fixed on Immich first (see [immich.md](./immich.md#single-sign-on-authentik)). It also includes a custom `groups` scope + property mapping (`mapping-group-membership`) per [K0lin/jellyfin-plugin-sso's providers.md#authentik](https://github.com/K0lin/jellyfin-plugin-sso/blob/main/providers.md#authentik), so the plugin's RBAC (`roleClaim: groups`) can map Authentik's `admins` group to Jellyfin admin access and `members`/`parents` to normal access.

The Jellyfin side is **also automated**, aside from one unavoidable one-time step (Jellyfin has no headless bootstrap):

1. **Plugin install** — an idempotent `extraInitContainers` entry in `config/forge/modules/jellyfin.yaml` downloads the latest [K0lin/jellyfin-plugin-sso](https://github.com/K0lin/jellyfin-plugin-sso) release from its manifest and unpacks it into the `config` PVC's `plugins/` dir on every pod start; skips entirely once already installed (no-op on every future restart/redeploy).

2. **Provider registration** — `.github/workflows/deploy-forge-deploy.yml` POSTs to `/sso/OID/Add/authentik` after every Helm deploy, using `JELLYFIN_API_KEY` + `JELLYFIN_SSO_CLIENT_SECRET` from Infisical. Idempotent (`Add` always overwrites) and retries briefly for ingress/cert readiness. Skips silently (doesn't fail the deploy) if `JELLYFIN_API_KEY` isn't set yet. Includes `schemeOverride: "https"` — Traefik terminates TLS and forwards plain HTTP to the pod, so without this the plugin builds an `http://` redirect_uri and Authentik rejects it with a "Redirect URI Error" (strict match against the registered `https://` one).

3. **One-time manual step**: `JELLYFIN_API_KEY` can only be minted via the web UI (Dashboard → API Keys), which itself requires the first-run admin setup wizard to have been completed once via the web UI. Once you have a key:
   ```powershell
   strata secret put JELLYFIN_API_KEY --value "<key>" -f config/environment.yaml
   ```
   After that, every future deploy registers/updates the SSO provider automatically — no further manual steps.

See [K0lin/jellyfin-plugin-sso's README](https://github.com/K0lin/jellyfin-plugin-sso) for the login-button snippet to add under Dashboard → General → Branding → Login disclaimer (still a manual, cosmetic, one-time step).

**MILESTONE (2026-08-28): confirmed working end-to-end in production** — "Sign in with SSO" successfully authenticates via Authentik after the `schemeOverride: "https"` fix above. All three bugs hit along the way (curl TLS trust + `set -e` retry-loop bug, `issuer_mode` mismatch, redirect_uri scheme mismatch) are resolved.

---

## Secrets

| Secret                       | Store     | Used by                                                                                                                                                                             |
| ---------------------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `JELLYFIN_SSO_CLIENT_SECRET` | Infisical | Authentik's Jellyfin OAuth2 provider + the plugin's `oidSecret` (both automated)                                                                                                    |
| `JELLYFIN_API_KEY`           | Infisical | Authenticates the automated SSO-provider-registration step in `deploy-forge-deploy.yml` — literal value, set manually once (Jellyfin has no API to generate its own key headlessly) |

---

## Verification checklist

- [x] `https://media.{domain}` — Jellyfin loads and is reachable from a browser
- [x] Media library shows content from `/mnt/storagebox/media`
- [x] SSO plugin installed and Authentik provider registered
- [x] "Sign in with SSO" login button works end-to-end (confirmed 2026-08-28)

---

## Still open

- Login-button HTML snippet (Dashboard → General → Branding) is still a manual, cosmetic, one-time step
