# Haven

Self-hosted family platform on Hetzner, defined as code and managed with
[strata](https://github.com/huybrechtsxyz/strata) v2:

- **Hearth** — a Docker Compose VM: Caddy, Authentik, Vaultwarden, Portainer, WUD.
- **Forge** — a single-node k3s VM: Immich, Jellyfin, Nextcloud, Kavita, Grimoire,
  FoundryVTT, Firefly III, Gatus, Homarr, pgAdmin, FileBrowser, Yuvomi.

strata renders Terraform, Helm values and the Compose file from the YAML in
[`config/`](config/); GitHub Actions runs them. Secrets live in Infisical and are
resolved at deploy time — never in git.

**Start here:** [GETTING_STARTED.md](GETTING_STARTED.md) — setup, the strata
commands and how a change reaches production.

📖 **Documentation:** [`docs/`](docs/) — build with Sphinx (`make html` from `docs/`)

| Section                                 | Description                                             |
| --------------------------------------- | ------------------------------------------------------- |
| [Design & Architecture](docs/design.md) | Two-node Hetzner platform — Core VPS + k3s Workload VPS |
| [Migration Guide](docs/migration.md)    | Living workbook — track progress as you go              |
| [Architecture](docs/architecture.md)    | System topology, node specs, data durability model      |
| [Guides](docs/guides/index.md)          | Prerequisites, setup, infrastructure, Hearth, Forge, backups |

## Quick reference

```bash
strata validate --strict                  # check every document in config/
strata deploy steps haven_deploy_prd      # what a deploy would run, in order
strata build run haven_deploy_prd         # render everything into build/haven_deploy_prd/
```

Tool versions (strata, Python, Terraform, Helm, ansible-core) are set in one
place: [`VERSIONS.env`](VERSIONS.env).
