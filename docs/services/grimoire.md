# Grimoire

> Grimoire — self-hosted TTRPG library manager (books, maps, tokens, audio, 3D models), self-hosted on Forge (k3s).

## Overview

[Grimoire](https://github.com/hunter-read/grimoire) runs on **Forge** (Hetzner CPX41, k3s), in the shared `documents` Kubernetes namespace alongside Nextcloud and Kavita. See [Forge](../guides/forge.md) for the node-level overview and [Kavita](./kavita.md)/[Nextcloud](./nextcloud.md) for the sibling apps it shares the docs sub-account tree with.

Unlike Kavita (a general PDF/EPUB/comic reader), Grimoire is purpose-built for tabletop RPG collections — it adds a full-text-searchable library across books, battlemaps, tokens, audio, and 3D models, plus per-user campaign tracking (a markdown notes wiki, linked resources, and a UVTT map editor for dynamic-lighting walls/doors/lights).

**Prerequisites:** `deploy-forge-init.yml` must have run successfully at least once with `configure_smb: true`, so the haven-data Storage Box's docs sub-account is SMB-mounted at `/mnt/haven-data-docs` on the host, and a DNS A record for `grimoire.{domain}` must point directly at Forge's public IP (Forge terminates its own ingress — see [Forge's design decision](../guides/forge.md#design-decision--forge-terminates-its-own-ingress)).

---

## What gets deployed

| Item      | Value                                                                                                                                                  |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Image     | `hunterreadca/grimoire:latest` (official image, includes Tesseract OCR — see [image variants](#image-variants) below)                                  |
| Namespace | `documents` (Kubernetes), module file `config/forge/modules/grimoire.yaml`                                                                             |
| Ingress   | Traefik (`className: traefik`), host `grimoire.{domain}`, TLS via cert-manager (`letsencrypt-staging` initially — see [TLS](#tls--cert-manager) below) |

No official Helm chart exists for Grimoire — deployed via a local chart at `services/forge/grimoire/`, same pattern as Kavita's.

### Image variants

The default tags (`latest`, pinned releases) include the Tesseract OCR engine so image-only/scanned PDFs are still full-text searchable. A smaller `-slim` variant (e.g. `:slim`) omits Tesseract if OCR isn't needed — not used here, since the point of self-hosting a scanned PDF collection is that older scanned rulebooks stay searchable.

---

## Storage — a dedicated subfolder of the haven-data docs mount

Grimoire reads from `/mnt/haven-data-docs/ttrpg` (hostPath, **read-only**) — a subpath of the same haven-data Storage Box docs sub-account SMB mount (see [Forge](../guides/forge.md)) that Nextcloud's External Storage and Kavita also point at. This is a dedicated `ttrpg/` subfolder, distinct from Kavita's `books/`, so the two apps never index the exact same files.

Mounting read-only is a deliberate deviation from Grimoire's own default (writable, so its in-app file manager can upload/rename/delete) — it matches the same "apps only read, Nextcloud is where family uploads happen" convention already established for Kavita in this repo. Practically: add/organize TTRPG files via Nextcloud (or directly on the Storage Box), then trigger/await a library scan in Grimoire — the in-app upload/rename/delete/duplicate-merge tools are unavailable as a result.

Grimoire's own database, full-text search index, and rendered thumbnails/cache are separate, local-disk storage (`persistence.data`, `local-path` PVC, 10Gi) — not part of the shared tree. Back this up the same way Kavita's config PVC is backed up.

---

## TLS — cert-manager

Grimoire's chart (`services/forge/grimoire/templates/ingress.yaml`) supports `ingress.annotations` and `ingress.tls`, wired up the same way as Kavita/Jellyfin/Immich/Nextcloud. `config/forge/modules/grimoire.yaml` currently sets `cert-manager.io/cluster-issuer: letsencrypt-staging` — `grimoire.huybrechts.xyz` has never had a cert issued before, so it needs its own HTTP-01 challenge to succeed at least once via staging before switching to prod (rate-limited to 5 certs/domain/week).

**Rollout steps** (same staging-first pattern as every other Forge app):

1. Deploy with `letsencrypt-staging` (already the current setting).
2. Confirm `kubectl describe certificate grimoire-tls -n documents` shows `Ready: True`.
3. Switch the annotation in `config/forge/modules/grimoire.yaml` to `letsencrypt-prod` and redeploy.
4. Re-verify `Ready: True` against the prod issuer before considering this done.

---

## First login

Grimoire has no pre-seeded admin account by default — the first person to register through the app's sign-up screen becomes the admin, same pattern as Kavita. Alternatively, accounts can be pre-seeded automatically from a `users.json` file (see upstream's [Users and permissions](https://docs.grimoirecodex.org/users-and-permissions) doc) — not wired up in this repo yet.

1. Visit `https://grimoire.huybrechts.xyz`.
2. Register the initial admin account.
3. From **Settings**, confirm the library has picked up content under `/library` (mapped from `/mnt/haven-data-docs/ttrpg` — see [Storage](#storage--a-dedicated-subfolder-of-the-haven-data-docs-mount) above), and trigger a scan if needed.

### Adding library content

Grimoire's own file manager is unavailable here (mounted read-only — see [Storage](#storage--a-dedicated-subfolder-of-the-haven-data-docs-mount) above), so files must land directly on `/mnt/haven-data-docs/ttrpg`, the same way Kavita's `books/` and Jellyfin's `media/` folders are populated: via the **Nextcloud** app (already SSO-logged-in), using an External Storage-mounted folder that points at this same path, or by copying files directly onto the Storage Box. Organize the folder per upstream's [Library structure](https://github.com/hunter-read/grimoire/blob/main/docs/library-structure.md) doc (`books/<system>/<category>/...`, plus top-level `maps/`, `tokens/`, `audio/`, `models/`). Trigger a scan from Grimoire's own dashboard, or wait for its scheduled scan.

---

## SSO

Grimoire supports OpenID Connect (Keycloak, Authentik, Authelia, and others per upstream's [OpenID Connect](https://docs.grimoirecodex.org/openid-connect) doc) but this is **not wired up in this repo yet** — unlike Kavita/Nextcloud/Immich/Jellyfin, there's no Authentik blueprint entry or automated client-secret patching for Grimoire. Until that's added, use local password accounts (see [First login](#first-login)).

---

## Verification checklist

- [ ] `https://grimoire.{domain}` — Grimoire loads over TLS (staging cert initially — browser will warn until switched to `letsencrypt-prod`)
- [ ] `kubectl describe certificate grimoire-tls -n documents` shows `Ready: True`
- [ ] Library scan picks up files under `/mnt/haven-data-docs/ttrpg`
- [ ] First-run admin account created (see [First login](#first-login))
- [ ] `kubectl get pods -n documents` shows the Grimoire pod healthy (`GET /api/health` readiness/liveness probes passing)

---

## Still open

- SSO (OIDC) is not automated — Authentik blueprint/client-secret wiring would need its own module change, same shape as Kavita's, once desired
- `SECRET_KEY` is left unset (upstream default): Grimoire generates and persists a random key under `DATA_PATH` on first boot, which is fine for a single-replica deployment — revisit only if this ever runs multiple replicas without a shared `DATA_PATH`
- `persistence.data` size (10Gi) is an initial estimate (database + search index + rendered thumbnails/cache) — monitor actual usage and grow the PVC if needed
- Pre-seeded users (`users.json`) not wired up — first-registration-becomes-admin is the only onboarding path today
