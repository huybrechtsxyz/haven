# Phase 3 — Hearth Server Initialization

> [← Phase 2](phase-2-infrastructure.md) | [Next: Phase 4 — Hearth Deploy →](phase-4-hearth-deploy.md)

Bootstrap the server: install Docker, create the `haven` service user, create the directory structure, and harden SSH.

**Automated:** Ansible playbook `deploy/ansible-init/hearth-init.yml` via GitHub Actions.  
**Runs once** on a fresh server. Safe to re-run — all tasks are idempotent.  
**Estimated time:** ~5 minutes.

---

## 3.1 — What hearth-init does

| Task                     | Details                                                                          |
| ------------------------ | -------------------------------------------------------------------------------- |
| Set timezone             | `Europe/Brussels`                                                                |
| Install packages         | `curl`, `ca-certificates`, `gnupg`, `ufw`, `fail2ban`                            |
| Install Docker           | Official Docker CE repository, pinned version                                    |
| Add Docker keyring       | `/etc/apt/keyrings/docker.asc`                                                   |
| Create `haven` group     | System group                                                                     |
| Create `haven` user      | System user, home `{{ haven_install_path }}`, member of `docker` group           |
| Create directory tree    | `/opt/haven/etc`, `/opt/haven/var/data`, `/opt/haven/var/certs`, etc.            |
| Set cert dir permissions | `/opt/haven/var/certs` → `root:root 0777` (Caddy needs to write as its own user) |
| SSH hardening            | `PermitRootLogin no`, `PasswordAuthentication no`, key-only auth                 |

---

## 3.2 — Directory structure created

```
/opt/haven/
├── etc/                    ← Config files (compose, Caddyfile, .env)
│   ├── caddy/
│   │   └── config/
│   └── authentik/
│       └── templates/      ← Owned by uid 1000 (authentik container user)
└── var/
    ├── certs/              ← Caddy TLS certificates (root:root 0777)
    └── data/
        ├── authentik/
        │   ├── postgresql/ ← root-owned, postgres container initializes
        │   └── media/      ← Owned by uid 1000 (authentik container user)
        │       └── public/
        ├── infisical/      ← root-owned parent, postgres container initializes
        └── vaultwarden/
```

> **Why uid 1000 for authentik dirs?** The `ghcr.io/goauthentik/server` container runs as uid 1000 (non-root). If the `media` and `templates` directories are owned by the `haven` system user (uid < 1000), the container process cannot traverse them → `PermissionError: [Errno 13] Permission denied: '/media/public'` → worker crashes at startup.

> **Why root-owned for postgres dirs?** The postgres container (uid 999) needs to `chown` and `initdb` on first start. Docker creates bind-mount paths as `root:root 0755` when the host path doesn't exist, which allows the entrypoint to take ownership. Pre-creating with the wrong owner breaks this.

---

## 3.3 — Triggering hearth-init

hearth-init runs automatically via the GitHub Actions pipeline on the first deploy.
The workflow detects a fresh server and runs the init playbook before hearth-deploy.

To run manually (e.g., debugging on a fresh server):

```powershell
# From workstation
ansible-playbook \
  deploy/ansible-init/hearth-init.yml \
  -i 91.98.78.36, \
  --private-key ~/.ssh/haven_ed25519 \
  -u root \
  -e @/tmp/deploy_vars.yml
```

---

## 3.4 — Verify

After init completes, SSH to the server and check:

```bash
# haven user exists and is in docker group
id haven
# uid=XXX(haven) gid=XXX(haven) groups=XXX(haven),XXX(docker)

# Docker is running
docker ps

# Directory structure exists
ls /opt/haven/etc
ls /opt/haven/var/certs

# SSH hardening
grep PermitRootLogin /etc/ssh/sshd_config
# PermitRootLogin no
```

---

## Checklist

- [ ] GitHub Actions pipeline ran hearth-init successfully
- [ ] `haven` user exists, in `docker` group
- [ ] Docker installed and running
- [ ] `/opt/haven` directory tree created
- [ ] SSH root login disabled
