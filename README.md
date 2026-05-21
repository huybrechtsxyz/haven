# haven

Configuration repository managed by [strata](https://github.com/huybrechtsxzy/strata).

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
