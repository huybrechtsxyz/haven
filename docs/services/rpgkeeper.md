# RPGKeeper

> RPGKeeper — universal digital character sheet manager (any TTRPG system), self-hosted on Forge (k3s), gated by Authentik forwardAuth.

## Overview

[RPGKeeper](https://github.com/SkewedAspect/rpgkeeper) (`rpgkeeper.com`) runs on **Forge** (Hetzner CPX41, k3s), in the shared `gaming` Kubernetes namespace alongside [FoundryVTT](./foundryvtt.md). Unlike FoundryVTT's world-hosting role, RPGKeeper is a lightweight, system-agnostic character sheet manager — a personal companion tool for tracking a character outside of any specific VTT session.

**Prerequisites:**
- A DNS A record for `rpgkeeper.{domain}` pointing directly at Forge's public IP (Forge terminates its own ingress).
- Family members/friends assigned to the `gaming` Authentik group (same group used for FoundryVTT/Grimoire).

---

## What gets deployed

| Item      | Value                                                                                                                                                                                                                                                   |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image     | `morgul/rpgkeeper:latest` — the project's own official, actively-maintained Docker image                                                                                                                                                                |
| Namespace | `gaming` (Kubernetes), module file `config/forge/modules/rpgkeeper.yaml`                                                                                                                                                                                |
| Ingress   | Traefik (`className: traefik`), host `rpgkeeper.{domain}`, TLS via cert-manager (`letsencrypt-prod` from the start — see [TLS](#tls--cert-manager) below), gated by Authentik forwardAuth (see [Access](#access--authentik-forwardauth-no-native-oidc)) |

No official Helm chart exists for RPGKeeper — deployed via a local chart at `services/forge/rpgkeeper/`, same pattern as FoundryVTT/Grimoire.

### Why RPGKeeper over CharKeeper

[CharKeeper](https://charkeeper.org/) was considered first, but ruled out for self-hosting: no Dockerfile, no docker-compose, no official/community container image anywhere, and it's deployed upstream via Capistrano (a traditional SSH-based Ruby deploy tool) rather than containers — self-hosting it would mean authoring a Dockerfile from scratch by reverse-engineering the Rails source, with no reference container to compare against. RPGKeeper has an official, actively-maintained image, SQLite storage (no separate database service), and a documented (if minimal) env var surface — a much lower-risk fit for this repo's Helm-module pattern.

---

## Storage — SQLite, dedicated local-path PVC

RPGKeeper's entire state — a single `rpgk.db` file plus the bundled `static.db` (game supplement data: weapons, armor, talents, etc. for every supported system) — lives under `/app/db`. No separate Postgres/Redis needed at all, even simpler than Grimoire's or Kavita's setup.

Backed by a dedicated `local-path` PVC (`persistence.data`, 2Gi — generous for what's essentially a small SQLite file). Same category as Grimoire's/Kavita's own app-owned data PVCs, not the haven-data Storage Box tree (this isn't shared reference content). Automatically covered by the existing local-path-PVC backup sweep in `deploy/ansible-forge/templates/backup.sh.j2` — no extra backup wiring needed.

### The static.db seeding problem

Per upstream's own README: mounting a volume at `/app/db` **shadows** the image's baked-in `static.db` file, so a fresh PVC would start with none of the game supplement data. The upstream docs suggest a manual `docker cp` step for this; this repo automates it instead with a k8s `initContainer` (`templates/deployment.yaml`) that mounts the **same** PVC at a different path (`/pvc-data`, not `/app/db`) so it can see both the image's real, unshadowed `static.db` and the PVC simultaneously — it copies `static.db` into the PVC only if not already present there (idempotent, safe on every redeploy/restart).

---

## TLS — cert-manager

**NOT staging-first**, same reasoning as FoundryVTT: `config/forge/modules/rpgkeeper.yaml` sets `cert-manager.io/cluster-issuer: letsencrypt-prod` immediately. The forwardAuth middleware's server-to-server HTTPS call back to this host fails certificate validation against a staging (untrusted-CA) cert — see [foundryvtt.md](foundryvtt.md#tls--cert-manager) for the full writeup, identical here.

---

## Access — Authentik forwardAuth, no native OIDC

RPGKeeper's only built-in multi-user authentication is **Google OAuth** (confirmed from its own README — `DOMAIN` + `CLIENT_ID`/`CLIENT_SECRET` via the Google Developer Console). No generic OIDC support, so — same as [FoundryVTT](foundryvtt.md#access--authentik-forwardauth-no-native-sso) — this uses the proven **Traefik forwardAuth → Authentik** pattern instead of a native provider.

**Design choice — `SINGLE_USER_MODE=true`, not Google OAuth**: rather than requiring everyone to have a Google account on top of an Authentik account, RPGKeeper runs in its own documented `SINGLE_USER_MODE` (upstream's own recommended setting for "personal home server deployments, not internet-facing"). Combined with the Authentik forwardAuth gate — which *does* make it effectively internet-facing but access-controlled — this satisfies the spirit of that constraint without layering a second, redundant auth system on top.

**Trade-off, by design**: `SINGLE_USER_MODE` means every person who passes the `gaming`-group forwardAuth gate shares **one** RPGKeeper account and sees the **same** character list — there is no per-user character separation. Acceptable for a small household/friend group where characters aren't sensitive from each other; revisit if that stops being true (the alternative is real Google OAuth accounts per person, dropping `SINGLE_USER_MODE`).

### How it works

Identical wiring to FoundryVTT — see [foundryvtt.md](foundryvtt.md#how-it-works) for the full explanation. In short: Traefik's `rpgkeeper-authentik-forwardauth` Middleware gates the ingress, Authentik's Proxy Provider (`mode: forward_single`, `external_host: https://rpgkeeper.huybrechts.xyz`) validates the session, access is gated to the `gaming` group (+ `admins`) via `policy-group-gaming`, and the request reaches RPGKeeper normally afterward (RPGKeeper ignores the injected `X-authentik-*` headers — it has no code that reads them, same as FoundryVTT).

### Cross-host outpost routing + prerequisites

Same three prerequisites as FoundryVTT/Firefly — see [foundryvtt.md](foundryvtt.md#prerequisites-all-required--same-three-firefly-needed) for the full writeup:

1. A `rpgkeeper.huybrechts.xyz` site block in Hearth's Caddyfile (`services/hearth/caddy/Caddyfile`) — added alongside the `finance.huybrechts.xyz`/`foundry.huybrechts.xyz` blocks. Requires `23 - Hearth - Deploy` to actually take effect (not just `22 - Hearth - Config`).
2. Traefik allowing ExternalName Services — already enabled cluster-wide since Firefly needed it first.
3. The `letsencrypt-prod` cert from the start (see [TLS](#tls--cert-manager) above).

The embedded outpost now has **three** Proxy Providers assigned (Firefly III, FoundryVTT, RPGKeeper) — all sharing the one "authentik Embedded Outpost" object, which is the expected/correct Authentik pattern for multiple `forward_single` apps (it multiplexes by the request's `Host` header, not by a separate outpost per app).

### Verifying the chain

`https://rpgkeeper.huybrechts.xyz/outpost.goauthentik.io/ping` should return **204 No Content** — isolates the forwardAuth plumbing from the app itself, same technique used for Firefly/FoundryVTT.

---

## Verification checklist

- [ ] `https://rpgkeeper.{domain}` — RPGKeeper loads over TLS (real `letsencrypt-prod` cert from first issuance)
- [ ] `kubectl describe certificate rpgkeeper-tls -n gaming` shows `Ready: True`
- [ ] `kubectl get pods -n gaming` shows the RPGKeeper pod healthy (init container completed, readiness/liveness probes against `GET /` passing)
- [ ] `kubectl exec` into the pod (or check via the app) confirms `static.db` is present under `/app/db` — the initContainer seeding worked
- [ ] `https://rpgkeeper.huybrechts.xyz/outpost.goauthentik.io/ping` returns **204 No Content**
- [ ] `rpgkeeper.huybrechts.xyz` site block present in `services/hearth/caddy/Caddyfile` and Hearth redeployed
- [ ] Visiting `https://rpgkeeper.huybrechts.xyz` redirects to Authentik login first, and only reaches RPGKeeper's own UI after a successful `gaming`-group login
- [ ] No login screen appears inside RPGKeeper itself (confirms `SINGLE_USER_MODE` is active)

---

## Still open

- `SINGLE_USER_MODE`'s shared-account trade-off (see [Access](#access--authentik-forwardauth-no-native-oidc) above) — revisit if per-person character separation becomes important; would mean switching to real Google OAuth accounts instead
- `persistence.data` size (2Gi) is a generous initial estimate for a SQLite-based app — unlikely to need growing, but monitor
- Cross-host outpost routing follows the same pattern proven for Firefly/FoundryVTT, but is still a relatively new mechanism in this repo — expect to iterate after the first real deploy + login attempt, same caveat those two carry
