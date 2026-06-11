# Haven

Configuration repository managed by [strata](https://github.com/huybrechtsxyz/strata).

📖 **Documentation:** [`docs/`](docs/) — build with Sphinx (`make html` from `docs/`)

| Section                                    | Description                                       |
| ------------------------------------------ | ------------------------------------------------- |
| [Design & Architecture](docs/design.md)    | High-level platform design and architecture notes |
| [Deployment Guide](docs/GUIDE.md)          | End-to-end setup and migration workbook           |
| [Full Documentation Index](docs/index.rst) | Sphinx documentation navigation root              |

## Getting Started

**Prerequisites:** `strata` installed (`uv tool install xyz-strata`) and `git`, `terraform` on PATH.

**First time setup:**

```bash
# Register this repo as the config source
strata repo add haven_config <repo-url> --branch main --clone

# Add a profile and point it at your config files
strata profile add <environment> --activate
strata ref config add haven-config --path "@haven_config/config/haven-config.yaml"
strata ref env add haven-env --path "@haven_config/environments/haven-env-<environment>.yaml"
```

**Day-to-day:**

```bash
strata status                                                  # workspace overview
strata validate run -f deployments/<deployment>.yaml           # lint & validate
strata build run -f deployments/<deployment>.yaml              # build artifact
strata deploy run -f deployments/<deployment>.yaml             # provision & deploy
```
