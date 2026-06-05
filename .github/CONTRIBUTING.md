# haven — Contributing

haven is a personal self-hosted infrastructure project. Contributions are welcome as bug reports, documentation improvements, and configuration fixes.

---

## What this project is

haven manages a self-hosted home server on Hetzner Cloud running three services:

- **Authentik** — SSO and identity provider
- **Vaultwarden** — password manager (Bitwarden-compatible)
- **Infisical** — secrets manager

Infrastructure is managed with Terraform (Hetzner Cloud provider), deployed via Ansible playbooks, and orchestrated by a GitHub Actions pipeline using the [strata CLI](https://github.com/huybrechtsxyz/strata).

---

## How to contribute

### Report an issue

Open a GitHub Issue. Include:
- What you expected vs what happened
- Which playbook, workflow step, or service is affected
- Relevant log output (mask any secrets — redact IPs, tokens, passwords)

### Suggest an improvement

Open a GitHub Issue labeled `enhancement`. Describe the problem you are solving, not just the implementation.

### Submit a change

1. Fork the repository and create a feature branch from `main`.
2. Make focused, logical commits.
3. Lint locally where possible (see [Checking your changes](#checking-your-changes)).
4. Open a PR against `main` with a short description of what changed and why.
5. Update `CHANGELOG.md` under `[Unreleased]`.

---

## Project structure

```
config/              YAML config files consumed by strata CLI
deploy/
  ansible-init/      One-time server bootstrap (hearth-init.yml)
  ansible-config/    Idempotent config enforcement (hearth-config.yml)
  ansible-deploy/    Docker Compose service deployment (hearth-deploy.yml)
docs/haven/          Operations guide (phases 0-6)
terraform/           Terraform root module + modules/ (Hetzner Cloud)
.github/
  workflows/         GitHub Actions pipeline (deploy.yml)
```

---

## Checking your changes

### Ansible

```bash
pip install ansible-lint
ansible-lint deploy/ansible-config/hearth-config.yml
ansible-lint deploy/ansible-deploy/hearth-deploy.yml
```

### Terraform

```bash
cd terraform
terraform init -backend=false
terraform validate
```

### YAML / workflow

```bash
pip install yamllint
yamllint .github/workflows/deploy.yml
```

---

## Conventions

- **Commit messages**: `type: short description` — e.g. `fix:`, `feat:`, `docs:`, `chore:`.
- **Ansible**: Use FQCN (`ansible.builtin.copy`, not `copy`). Guard sensitive tasks with `no_log: true`. All tasks in `hearth-config.yml` must be idempotent.
- **Secrets**: Never commit secrets or credentials. Use GitHub Secrets for pipeline values; pass sensitive values via Ansible `--extra-vars` for manual runs.
- **Docs**: Update the relevant phase doc in `docs/haven/` when changing playbooks or workflow flags.

---

## Security

Do not include secrets, credentials, or private data in PRs or issues. For security vulnerabilities, follow [SECURITY.md](./SECURITY.md).

---

## Questions & Support

See [SUPPORT.md](./SUPPORT.md) for where to get help.

Thank you for contributing!
