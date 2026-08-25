# Future Ideas

> A running wishlist of self-hosted apps that look like a good fit for the haven family platform.

This is a parking lot for ideas, not a roadmap. Nothing here is committed — when an entry is actually
deployed, move it into [architecture.md](architecture.md) / [design.md](design.md) and the relevant
[guides](guides/index.md), then remove it from this list (or strike it through with a note).

Already-deployed services (Authentik, Vaultwarden, Caddy, Portainer, WUD, Immich, Jellyfin, Kavita,
Nextcloud, Healthchecks-io, UptimeRobot, Gatus) are **not** repeated here — see the `docs/services/`
folder for those.

---

## Monitoring & Observability

- **[Uptime Kuma](https://github.com/louislam/uptime-kuma)** — self-hosted uptime monitoring with a
  nice status page; could complement or replace UptimeRobot/Gatus for internal checks without
  relying on an external free tier.
- **Grafana + Prometheus + Loki (LGTM-ish stack)** — metrics + logs + dashboards for Hearth/Forge
  nodes and containers (node-exporter, cAdvisor). Heavier footprint, worth it once there are enough
  services to justify a real dashboard.
- **[Grafana Alloy](https://github.com/grafana/alloy)** / OpenTelemetry Collector — unified metrics
  and logs shipping if the Grafana stack lands.
- **[Dozzle](https://github.com/amir20/dozzle)** — lightweight real-time Docker log viewer, much
  cheaper than a full Loki stack if logs are just needed for troubleshooting.
- **[ntfy](https://github.com/binwiedermann/ntfy)** or **[Gotify](https://github.com/gotify/server)**
  — lightweight self-hosted push notifications; a natural sink for alerts from Uptime Kuma,
  Healthchecks, n8n workflows, and Firefly III webhooks instead of relying on email/external services.

## Networking & DNS

- **[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)** or **[Technitium DNS](https://github.com/TechnitiumSoftware/DnsServer)**
  — network-wide ad/tracker blocking + local DNS resolution for the home network.
- **[Tailscale](https://tailscale.com/)** or **[Headscale](https://github.com/juanfont/headscale)**
  (self-hosted control server) — mesh VPN for secure access to Hearth/Forge and home devices without
  exposing services publicly.
- **[Nginx Proxy Manager](https://github.com/NginxProxyManager/nginx-proxy-manager)** — only relevant
  if Caddy ever becomes a bottleneck; low priority since Caddy already covers this.

## Communication

- **[Matrix (Synapse or Conduit)](https://github.com/element-hq/synapse)** + **[Element](https://github.com/element-hq/element-web)**
  — self-hosted family chat with E2E encryption; overkill for a small household but a solid pick if
  moving off commercial chat apps ever becomes a goal.
- **[Jitsi Meet](https://github.com/jitsi/jitsi-meet)** — self-hosted video calls, no account needed
  for guests; pairs naturally with Matrix/Element above.

## Automation & Productivity

- **[n8n](https://github.com/n8n-io/n8n)** — workflow automation (glue between Healthchecks, Vaultwarden,
  Infisical, notifications, etc.). Also the natural automation layer for **Firefly III**, whose REST
  API covers nearly every part of the app (transactions, accounts, budgets, rules, reports) — see the
  Firefly III entry below for concrete automation ideas.
- **[Home Assistant](https://www.home-assistant.io/)** — home automation hub; candidate for Forge if
  smart-home devices get added to the household.
- **[Vikunja](https://github.com/go-vikunja/vikunja)** or **[Wekan](https://github.com/wekan/wekan)**
  — family task/kanban boards.
- **[Homebox](https://github.com/sysadminsmedia/homebox)** — home inventory / asset tracker (warranty
  dates, receipts, locations); handy for a family keeping track of what they own.

### Personal Finance (MoneyWiz-style)

Currently using MoneyWiz (iOS) for multi-account tracking, budgets, and net worth. Usage is mostly
**cashflow/net-worth tracking, not envelope budgeting** — which points fairly clearly at Firefly III
over Actual Budget:

- **[Firefly III](https://github.com/firefly-iii/firefly-iii)** — **preferred pick**. Double-entry
  bookkeeping models cashflow (transfers, income, expenses) directly rather than forcing a
  zero-based budget, has multi-account net worth, recurring transactions, rules/automation, reports,
  and a real API. Bank sync via the companion
  **[Firefly III Data Importer](https://github.com/firefly-iii/data-importer)** (CSV,
  Nordigen/GoCardless for many EU banks — useful since Hetzner/Infomaniak side is EU-based already).
  No official first-party app, but the API has spawned a small ecosystem of iOS clients — see
  below.

  **Firefly III iOS clients** (unofficial, community-built against its REST API):
  - **[Abacus](https://github.com/victorbalssa/abacus)** — most established option (~850 stars),
    React Native, free, iOS + Android, actively maintained. Best starting point.
  - **[Hotaru](https://github.com/adityask98/Hotaru)** — newer native SwiftUI iOS app, actively
    updated but small/early project.
  - **Lucciola** — another newer native SwiftUI iOS client, worth watching as it matures.
  - Fallback: the Firefly III web UI works fine as an installed PWA ("Add to Home Screen") if none
    of the native clients feel solid enough.

  **Automation via the API**: Firefly III exposes a full REST/OpenAPI surface plus a native
  **webhook** system (fires on transaction create/update/delete, budget limits, etc.), so it pairs
  well with **n8n** for things like:
  - Notify (Healthchecks/ntfy/etc.) when a large or unrecognized transaction lands.
  - Auto-tag/auto-categorize imported transactions beyond Firefly's built-in rule engine.
  - Push monthly cashflow/net-worth summaries to a family channel.
  - Cross-check recurring transactions against Infisical-tracked subscriptions for drift detection.
  Firefly's own **rule engine** already handles a lot of this in-app — reach for n8n only for
  cross-system workflows that need data outside Firefly itself.
- **[Actual Budget](https://github.com/actualbudget/actual)** — YNAB-style zero-based envelope
  budgeting, self-hosted sync server, official iOS/Android apps — nicer native mobile feel, but the
  envelope-budgeting model is a mismatch for cashflow-style tracking; **deprioritized** unless
  budgeting habits change.
- **[Maybe](https://github.com/maybe-finance/maybe)** — newer, nicer-looking net-worth + budgeting
  app (spiritually closer to MoneyWiz/Copilot/Monarch), self-hostable via Docker; still maturing —
  worth a watch rather than an immediate deploy. No native mobile app yet (web-first).

Realistic path: pilot **Firefly III** on Forge behind Authentik SSO for household bookkeeping, keep
MoneyWiz for day-to-day quick entry on the phone (PWA install as a fallback) since it's the better
cashflow-tracking fit, not just the "has an app" fallback.

### Health & Fitness (Bevel-style)

Currently using [Bevel](https://www.bevel.health/) (iOS) as a wearable/health "interpretation
layer" — it doesn't track anything itself, it reads Apple HealthKit data (Apple Watch, Garmin, Oura,
etc.) and turns it into sleep/recovery/strain/stress scores, nutrition logging, strength-training
plans, and AI coaching, plus a health-records store. **There is no direct open-source, self-hosted
clone of Bevel** — the closest realistic setup is assembling the pieces rather than a single app:

- **Apple Health export → self-hosted dashboards**: use an export bridge (e.g. the "Health Auto
  Export" iOS app — proprietary but widely used, one-time purchase) to push HealthKit data as a
  webhook into **n8n**, landing in **InfluxDB**, visualized with **Grafana** — reuses the
  Grafana/Prometheus/Loki stack already listed under Monitoring & Observability instead of adding a
  new stack just for health data.
- **[wger](https://github.com/wger-project/wger)** — self-hosted workout/strength-training manager
  (exercise database, routines, progress charts) — the closest FOSS analog to Bevel's "Strength
  Builder" feature specifically.
- **[Home Assistant](https://www.home-assistant.io/)** (already listed above) — has community
  integrations for some wearables/health data too, if the automation angle (e.g. smart alarms based
  on sleep data) matters more than dashboards.
- Health records storage is already covered by **Nextcloud** (already deployed) rather than needing
  a dedicated tool.

Realistic path: this one stays a **"nice to have, not a priority"** — the AI-coaching/insight
generation that makes Bevel useful has no good self-hosted equivalent yet, so replacing it isn't
worth it. If the Grafana stack gets deployed anyway for infra monitoring, piping Apple Health data
into it as a bonus dashboard is low-effort; don't build a whole stack just for this.

## AI / LLM

- **[Ollama](https://github.com/ollama/ollama)** + **[Open WebUI](https://github.com/open-webui/open-webui)**
  — local LLM runtime with a chat UI; would need a Forge node with enough RAM/CPU (or GPU) to be useful.
- **[Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx)** — document management with OCR;
  not strictly "AI" but often paired with local LLM tooling for search/summarization.

## Media & Family-Friendly Apps

- **[Audiobookshelf](https://github.com/advplyr/audiobookshelf)** — audiobook/podcast server,
  natural companion to Jellyfin/Kavita.
- **[Immich](https://github.com/immich-app/immich)** companion apps — already deployed; consider
  **[PhotoPrism](https://github.com/photoprism/photoprism)** only if Immich ever falls short.
- **[Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF)** — family-friendly PDF toolbox
  (merge/split/convert) as a self-hosted alternative to random online tools.
- **[Homepage](https://github.com/gethomepage/homepage)** or **[Homarr](https://github.com/ajnart/homarr)**
  — a family-facing dashboard/landing page linking to all the deployed apps.
- **[FreshRSS](https://github.com/FreshRSS/FreshRSS)** — self-hosted RSS reader.
- **[Recipya](https://github.com/reaper47/recipya)** or **[Mealie](https://github.com/mealie-recipes/mealie)**
  — family recipe manager and meal planner.
- **[Navidrome](https://github.com/navidrome/navidrome)** — self-hosted music streaming server
  (Subsonic-compatible, so lots of existing mobile clients), natural sibling to Jellyfin/Audiobookshelf.
- **[Calibre-Web](https://github.com/janeczku/calibre-web)** — ebook library/reader web UI on top of a
  Calibre library, complementary to Kavita (which focuses on comics/manga).
- **Sonarr / Radarr / Prowlarr / Bazarr** (the "*arr stack") — media library automation: fetch
  metadata, rename/organize files, and pull subtitles for an existing Jellyfin library. Only worth it
  once the media library is big enough that manual organizing gets tedious.
- **[Overseerr](https://github.com/sct/overseerr)** / **[Jellyseerr](https://github.com/Fallenbagel/jellyseerr)**
  — lets family members submit "please add this" requests against the Jellyfin library instead of
  asking directly; Jellyseerr integrates natively with Jellyfin (already deployed).

## Docs & Knowledge

- **[BookStack](https://github.com/BookStackApp/BookStack)** or **[Wiki.js](https://github.com/requarks/wiki)**
  — family wiki for household docs: appliance manuals, Wi-Fi/guest network info, "how we set this up"
  notes — a nice companion to this very `docs/` folder but for household (not infra) knowledge.
- **[Trilium Notes](https://github.com/TriliumNext/Notes)** or a self-hosted **[Joplin server](https://github.com/laurent22/joplin)**
  — synced personal/family notes across devices.
- **[Linkding](https://github.com/sissbruecker/linkding)** — minimalist self-hosted bookmark manager.
- **[Wallabag](https://github.com/wallabag/wallabag)** — self-hosted "read it later"/article archiver.

## Developer Tools

- **[Gitea](https://github.com/go-gitea/gitea)** or **[Forgejo](https://codeberg.org/forgejo/forgejo)**
  — lightweight self-hosted git forge; only relevant for personal/private projects that shouldn't live
  on GitHub, since haven itself is already GitHub-hosted with working CI/CD.
- **[Renovate](https://github.com/renovatebot/renovate)** (self-hosted runner) — automated dependency
  update PRs; more useful once there are enough haven-adjacent repos/services to make manual bumping
  tedious.
- **[Coder](https://github.com/coder/coder)** — self-hosted answer to GitHub Codespaces / coder.com
  cloud: on-demand, browser- or IDE-connected dev workspaces defined as **Terraform templates**
  (Docker containers, Kubernetes pods, VMs), auto-shutdown when idle. Fits naturally on Forge's k3s
  cluster and matches haven's existing Terraform-first IaC approach — connect via the VS Code/
  JetBrains remote extensions or a browser-based editor. Core server is AGPL-licensed/free; some
  enterprise features (SSO variants, audit logging at scale) are paid — irrelevant at family-lab size.
- **[code-server](https://github.com/coder/code-server)** — much lighter alternative if full
  workspace orchestration is overkill: just VS Code running in a browser against one persistent
  container, no Terraform templates or multi-workspace management needed.
- **[DevPod](https://github.com/loft-sh/devpod)** — client-side tool (no server component) that spins
  up standard `devcontainer.json`-based dev environments against Docker, Kubernetes, or cloud
  providers; a good low-commitment way to try "cloud dev environments" without deploying a platform.

## Backup & Storage

- **[Duplicati](https://github.com/duplicati/duplicati)** — only if BorgBackup ever needs a
  friendlier UI for ad-hoc restores; low priority since Borg already covers Tier 1 backups.
- **[Kopia](https://github.com/kopia/kopia)** — another BorgBackup alternative with a built-in web UI
  and scheduling; same low priority as Duplicati, just a different flavor.
- **[Syncthing](https://github.com/syncthing/syncthing)** — peer-to-peer file sync across family
  devices, complementary to Nextcloud/kDrive rather than a replacement.

---

## Notes

- Prefer apps with active maintenance, a Docker/Helm-friendly deployment story (fits the
  Compose-on-Hearth / k3s-on-Forge model), and reasonable resource footprints for a CX23/CPX41-class
  VPS.
- Anything requiring GPU (e.g. larger local LLMs) is deferred until/unless dedicated hardware is
  considered, since Hearth/Forge are currently CPU-only Hetzner VPS nodes.
- When promoting an idea from this list, follow the existing module pattern under
  `config/forge/modules/` or `config/hearth/modules/` and add a doc page under `docs/services/`.
