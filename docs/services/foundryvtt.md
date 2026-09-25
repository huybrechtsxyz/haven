# Foundry Virtual Tabletop

> Foundry VTT — self-hosted virtual tabletop server, licensed via your own foundryvtt.com account, self-hosted on Forge (k3s).

## Overview

[Foundry Virtual Tabletop](https://foundryvtt.com/) runs on **Forge** (Hetzner CPX41, k3s), in its own dedicated `gaming` Kubernetes namespace. Unlike Kavita/Nextcloud/Grimoire, it shares no storage tree with any other app — see [Storage](#storage--dedicated-local-path-not-the-shared-storage-box-tree) below.

**Prerequisites:**
- A [foundryvtt.com](https://foundryvtt.com/auth/register/) account with a **purchased software license**.
- A DNS A record for `foundry.{domain}` pointing directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).
- `FOUNDRY_USERNAME`, `FOUNDRY_PASSWORD`, and `FOUNDRY_ADMIN_KEY` added to Infisical **manually** (not strata-generated — see [Credentials](#credentials--manually-provided-in-infisical) below).

---

## What gets deployed

| Item      | Value                                                                                                                                                                                                                                                |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image     | `ghcr.io/felddy/foundryvtt:14` — the standard community image (does **not** bundle the Foundry software itself, see below)                                                                                                                           |
| Namespace | `gaming` (Kubernetes), module file `config/forge/modules/foundryvtt.yaml`                                                                                                                                                                            |
| Ingress   | Traefik (`className: traefik`), host `foundry.{domain}`, TLS via cert-manager (`letsencrypt-prod` from the start — see [TLS](#tls--cert-manager) below), gated by Authentik forwardAuth (see [Access](#access--authentik-forwardauth-no-native-sso)) |

No official Helm chart exists for Foundry — deployed via a local chart at `services/forge/foundryvtt/`, same pattern as Kavita/Grimoire.

### Why `felddy/foundryvtt` and not an official image

Foundry's EULA doesn't allow redistributing the software itself in a public Docker image. The [felddy/foundryvtt-docker](https://github.com/felddy/foundryvtt-docker) image (934+ stars, actively maintained) instead **downloads your own licensed copy at container startup**, using your foundryvtt.com credentials (`FOUNDRY_USERNAME`/`FOUNDRY_PASSWORD`) or a presigned download URL (`FOUNDRY_RELEASE_URL`) — this repo uses the credentials approach. Image tag `:14` tracks the latest release compatible with that major version, per upstream's own recommendation (avoids an inadvertent major-version jump that could be incompatible with saved worlds).

---

## Storage — dedicated local-path, NOT the shared Storage Box tree

Foundry's **entire state** — the downloaded application software itself, config, worlds/campaigns (a LevelDB-style datastore), installed modules/systems, and every uploaded asset (maps, tokens, audio) — lives under `/data`, backed by a dedicated `local-path` PVC (`persistence.data`, 30Gi initial size).

This is a deliberate departure from Kavita/Nextcloud/Grimoire's pattern of mounting the haven-data Storage Box's SMB tree: those apps serve **read-only reference content** where SMB/CIFS is a perfectly fine backing store. Foundry's `/data` is the opposite — a **live, frequently-written** datastore during active play (world saves happen continuously), and network filesystems risk locking/corruption issues for that access pattern. So it gets its own local-disk PVC instead, same category as Grimoire's `persistence.data` or Kavita's `persistence.config`.

**Backup is automatic and needs no extra wiring**: `deploy/ansible-forge/templates/backup.sh.j2` already discovers and tars every PVC with `storageClassName: local-path` across the whole cluster generically — Foundry's data gets swept up in the existing nightly BorgBackup run alongside Jellyfin/Kavita/Gatus/etc.'s own local-path PVCs, with zero per-app configuration.

30Gi is an initial estimate — grow it if uploaded maps/tokens/audio accumulate faster than expected (see [Still open](#still-open)).

---

## Credentials — manually provided in Infisical

Unlike almost every other secret in this repo, `FOUNDRY_USERNAME`/`FOUNDRY_PASSWORD`/`FOUNDRY_ADMIN_KEY` are **not** strata-generated (`config/environment.yaml` has no `generate:` block for them) — they're your real foundryvtt.com account credentials and a chosen admin/GM password, entered directly into Infisical by hand before the first deploy. Routed through the `foundryvtt-secrets` K8s Secret (module `config/forge/modules/foundryvtt-secrets.yaml`, chart `services/forge/foundryvtt-secrets/`) via `secretKeyRef` — the same "dedicated tiny Secret-only chart" pattern used by `grimoire-secrets`/`nextcloud-secrets`/`homarr-secrets`.

`FOUNDRY_ADMIN_KEY` is applied fresh **on every container startup** — this is the single shared password used to log in as GM/admin in Foundry's own join screen (Foundry has no per-user account system; see [Access](#access--no-native-sso) below).

---

## The stable-hostname requirement

Foundry **binds its software license to the container/pod hostname** (confirmed in felddy/foundryvtt-docker's own docs): "If no hostname is set, the runtime assigns a random container ID on each start, causing license verification to fail after every restart." The chart sets `spec.template.spec.hostname: "{{ .Release.Name }}"` explicitly (renders to the fixed string `foundryvtt`) — Helm's `Release.Name` is stable across redeploys/restarts (it only changes if the release itself is renamed), which satisfies this requirement without any extra values plumbing. **Do not remove this** — without it, every pod restart would re-trigger Foundry's license activation flow.

---

## TLS — cert-manager

**NOT staging-first**, unlike every other Forge app without forwardAuth in front of it: `config/forge/modules/foundryvtt.yaml` sets `cert-manager.io/cluster-issuer: letsencrypt-prod` immediately. See [Access](#access--authentik-forwardauth-no-native-sso)'s prerequisites section for why the usual staging-first pattern is actively broken here — the forwardAuth middleware's server-to-server HTTPS call back to this host fails certificate validation against a staging (untrusted-CA) cert.

1. Deploy — `foundry.huybrechts.xyz` gets a real `letsencrypt-prod` cert on first issuance (rate-limited to 5 certs/domain/week, so this should only need to happen once).
2. Confirm `kubectl describe certificate foundryvtt-tls -n gaming` shows `Ready: True`.

---

## Access — Authentik forwardAuth (no native SSO)

Foundry has **no OIDC/SSO integration at all** — confirmed against felddy/foundryvtt-docker's own deployment guides (Kubernetes, Podman, Docker Compose, plus Caddy/nginx/Cloudflare-Tunnel recipes — none mention OIDC/SSO/Authentik). Its own auth model has no per-user account/header concept either: a World has a fixed list of Users with a single shared admin/GM password (`FOUNDRY_ADMIN_KEY`) plus optional per-player passwords, configured inside Foundry itself once logged in.

Since there's no OAuth client to register on Foundry's side, this uses the same **Traefik forwardAuth → Authentik** pattern already proven for Firefly III (see [firefly.md](firefly.md)) instead of a native OIDC provider — a reverse-proxy-level auth check gates every request *before* it reaches the Foundry pod.

**Important difference from Firefly**: Firefly consumes the injected `X-authentik-email` header to auto-log a matching user in (`remote_user_guard`). Foundry has no equivalent header-based guard, so this forwardAuth **only gates whether you can reach Foundry's login screen at all** (via the `gaming` Authentik group) — it does not select which Foundry user you are. Foundry's own user picker + per-user passwords remain a fully independent second layer underneath.

### How it works

1. Traefik's `foundryvtt-authentik-forwardauth` Middleware (`services/forge/foundryvtt/templates/middleware.yaml`) is attached to Foundry's ingress via the `traefik.ingress.kubernetes.io/router.middlewares` annotation. On every request, Traefik calls out to Authentik's outpost to check the session before forwarding to Foundry.
2. Authentik's Proxy Provider (`deploy/ansible-hearth/templates/authentik-blueprint.yaml.j2`, `mode: forward_single`, `external_host: https://foundry.huybrechts.xyz`) issues/validates the session.
3. Access is gated to the `gaming` group (+ `admins`, via `policy-group-gaming`) — the same group used for Grimoire, not the blanket family policy.
4. Once past the forwardAuth check, the request reaches Foundry completely normally — Foundry ignores the injected `X-authentik-*` headers entirely (it has no code that reads them) and shows its own ordinary login/user-picker screen.

### The cross-host outpost routing problem

Authentik's "forward auth (single application)" mode requires `<external_host>/outpost.goauthentik.io/*` — on **Foundry's own domain** — to be routed to the outpost that actually handles the login callback/session-cookie exchange for that domain. Authentik (and its embedded outpost) runs on **Hearth** (Docker Compose); Foundry runs on **Forge** (k3s) — a different host. Same bridge as Firefly's:

- `templates/service-outpost.yaml` — a plain Kubernetes `ExternalName` Service pointing at `auth.huybrechts.xyz` (with `traefik.ingress.kubernetes.io/service.serversscheme: https`).
- `templates/ingress-outpost.yaml` — a second Ingress on the same `foundry.huybrechts.xyz` host, routing the `/outpost.goauthentik.io` path prefix to that ExternalName Service, with **no** forwardAuth middleware attached (must stay reachable unauthenticated, or the login flow would loop).

### Prerequisites (all required — same three Firefly needed)

1. **A `foundry.huybrechts.xyz` site block in Hearth's Caddyfile** (`services/hearth/caddy/Caddyfile`) — added alongside the existing `finance.huybrechts.xyz` block. Traefik preserves the original `Host` header when proxying to an ExternalName Service, so Caddy receives `Host: foundry.huybrechts.xyz` over a connection whose SNI is `auth.huybrechts.xyz`. Without a matching site block Caddy answers 404 and the outpost is never reached. Uses `tls internal` for the same reason Firefly's does (Caddy can never obtain a public cert for a name that resolves to Forge). Requires a Hearth redeploy.
2. **Traefik must be allowed to route to ExternalName Services** — already enabled cluster-wide (k3s `HelmChartConfig` written by `deploy/ansible-forge/forge-init.yml`) since Firefly needed it first. No new work needed here, but confirm it's still in place if Traefik was ever reset.
3. **A production certificate from the start, not `letsencrypt-staging`** — `config/forge/modules/foundryvtt.yaml` sets `letsencrypt-prod` immediately, deliberately breaking the usual staging-first pattern. The forwardAuth middleware makes a server-to-server HTTPS call back to `foundry.huybrechts.xyz`, and Go verifies that certificate against the system trust store — a staging cert is signed by an untrusted CA and every request 500s with `x509: certificate signed by unknown authority`.

### Verifying the chain

`https://foundry.huybrechts.xyz/outpost.goauthentik.io/ping` should return **204 No Content**. That exercises Traefik's outpost route → ExternalName Service → Caddy → Authentik's embedded outpost without involving Foundry or a login flow, so it isolates the plumbing from the application — same technique used for Firefly.

### Debugging — isolate app problems from Authentik wiring problems

Temporarily set in the module config, redeploy, and confirm Foundry's own login screen loads directly with no forwardAuth in front of it:

```yaml
sso:
  enabled: false
```

If that loads fine, the app/ingress/cert/PVC are all healthy and the fault is in the forward-auth path specifically. Remember to set `sso.enabled: true` back afterward.

---

## First login / setup

1. Watch the first deploy's logs closely — first boot downloads the licensed Foundry distribution (tens to hundreds of MB) before the server even starts listening, which can take several minutes depending on network speed: `kubectl logs -n gaming deploy/foundryvtt -f`.
2. Visit `https://foundry.huybrechts.xyz` once the pod is `Ready`.
3. Log in with the `FOUNDRY_ADMIN_KEY` value (from Infisical) as the GM/admin.
4. Create your first World (system + game), install any purchased modules/systems from Foundry's own in-app browser, and invite players with the site URL + whatever join password you configure inside Foundry.

---

## Verification checklist

- [ ] `https://foundry.{domain}` — Foundry loads over TLS (real `letsencrypt-prod` cert from first issuance — no staging step here, see [TLS](#tls--cert-manager) above)
- [ ] `kubectl describe certificate foundryvtt-tls -n gaming` shows `Ready: True`
- [ ] `kubectl get pods -n gaming` shows the FoundryVTT pod healthy (readiness/liveness probes against `GET /` passing)
- [ ] First boot's license download/activation succeeded (check pod logs — look for a successful license verification, not a repeated activation loop)
- [ ] `https://foundry.huybrechts.xyz/outpost.goauthentik.io/ping` returns **204 No Content** (verifies the forwardAuth plumbing independently of Foundry — see [Verifying the chain](#verifying-the-chain))
- [ ] `foundry.huybrechts.xyz` site block present in `services/hearth/caddy/Caddyfile` and Hearth redeployed
- [ ] Visiting `https://foundry.huybrechts.xyz` redirects to Authentik login first, and only reaches Foundry's own login/user-picker screen after a successful `gaming`-group login
- [ ] Logging in with `FOUNDRY_ADMIN_KEY` works (after clearing the Authentik forwardAuth gate)
- [ ] A pod restart does **not** re-trigger license activation (confirms the stable-hostname setting is working)

---

## Still open

- Cross-host outpost routing is **not yet live-verified** — same caveat Firefly's own docs carry: this is the riskiest/newest part of the change, expect to iterate after the first real deploy + login attempt
- `persistence.data` size (30Gi) is an initial estimate — monitor actual usage (uploaded maps/tokens/audio add up fast) and grow the PVC if needed
- Foundry's own automatic "Update Software" tab is disabled by design in this image — upgrades happen by bumping the image tag and redeploying instead (see upstream's [Updating](https://github.com/felddy/foundryvtt-docker#updating) docs)
