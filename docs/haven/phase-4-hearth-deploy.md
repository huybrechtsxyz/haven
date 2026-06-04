# Phase 4 — Core Services Deployment

> [← Phase 3](phase-3-hearth-init.md) | [Next: Phase 5 — Service Setup →](phase-5-service-setup.md)

Deploy all 9 containers and obtain TLS certificates.

**Automated:** Ansible playbook `deploy/ansible-deploy/hearth-deploy.yml` via GitHub Actions on every push to `haven-initial`.  
**Idempotent:** Safe to re-run. Only changed items (new Caddyfile, missing certs, etc.) trigger actions.  
**Estimated time:** ~2 minutes per pipeline run (plus 60s stabilization wait).

---

## 4.1 — The 9 containers

| Container | Image | Purpose |
|-----------|-------|---------|
| `haven-caddy-1` | `caddy:2-alpine` | Reverse proxy + TLS termination |
| `haven-authentik-server-1` | `ghcr.io/goauthentik/server:2024.12.3` | Authentik web server |
| `haven-authentik-worker-1` | `ghcr.io/goauthentik/server:2024.12.3` | Authentik Celery worker |
| `haven-authentik-db-1` | `postgres:16-alpine` | Authentik database |
| `haven-authentik-redis-1` | `redis:7-alpine` | Authentik task queue |
| `haven-vaultwarden-1` | `vaultwarden/server:latest` | Password manager |
| `haven-infisical-1` | `infisical/infisical:latest` | Secrets manager |
| `haven-infisical-db-1` | `postgres:16-alpine` | Infisical database |
| `haven-infisical-redis-1` | `redis:7-alpine` | Infisical cache |

---

## 4.2 — What hearth-deploy does (in order)

1. **Write vars file** from GitHub Secrets → `/tmp/deploy_vars.yml` on runner
2. **Create directories** — caddy config, vaultwarden data
3. **Create authentik dirs** owned by uid `1000` (media, templates, media/public)
4. **Create postgres parent dirs** owned by root (postgres containers initialize these)
5. **Copy `docker-compose.yml`** to `/opt/haven/etc/`
6. **Copy `Caddyfile`** to `/opt/haven/etc/caddy/`
7. **Write `.env`** with all service secrets (no_log: true)
8. **Stop orphan stacks** from previous runs with wrong project name
9. **Release ports** 80/443 if held by stray processes
10. **Pull Docker images** (always latest for compose-defined versions)
11. **`docker compose up -d`** — start/update all 9 containers
12. **Restart authentik containers** — ensures server + worker pick up correct `/media` ownership
13. **Restart Caddy** — only if Caddyfile changed OR no LE production certs found
14. **Wait 60 seconds** — containers stabilize, ACME challenges complete
15. **Diagnostics** — container states, authentik logs, infisical logs, TLS cert status, port checks

---

## 4.3 — TLS certificates (Caddy + Let's Encrypt)

Caddy obtains real production certificates automatically via ACME HTTP-01 challenge.

The Caddyfile is minimal:

```caddy
{
    email admin@huybrechts.xyz
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

auth.huybrechts.xyz     { reverse_proxy authentik-server:9000 }
vault.huybrechts.xyz    { reverse_proxy vaultwarden:80 }
secrets.huybrechts.xyz  { reverse_proxy infisical:8080 }
```

Caddy restarts **only when** the Caddyfile changed **or** no production LE certs exist.
It does NOT restart every deployment — this avoids unnecessary ACME requests and rate limiting.

Cert storage: `/opt/haven/var/certs/caddy/certificates/acme-v02.api.letsencrypt.org-directory/`

> **Note:** Caddy may print "Caddyfile input is not formatted" — this is cosmetic only and does not affect operation.

---

## 4.4 — The `.env` file

The `.env` file is written by Ansible from GitHub Secrets. It is never committed to the repo.

Key variables (see `config/env-haven-prd.yaml` for full list):

```env
AUTHENTIK_SECRET_KEY=<from AUTHENTIK_SECRET_KEY secret>
AUTHENTIK_POSTGRESQL__PASSWORD=<from AUTHENTIK_POSTGRESQL_PASSWORD secret>
VAULTWARDEN_ADMIN_TOKEN=<from VAULTWARDEN_ADMIN_TOKEN secret>
INFISICAL_AUTH_SECRET=<from INFISICAL_AUTH_SECRET secret>        # must be 64 hex chars
INFISICAL_ENCRYPTION_KEY=<from INFISICAL_ENCRYPTION_KEY secret>  # must be 32 chars exactly
INFISICAL_POSTGRESQL__PASSWORD=<from INFISICAL_POSTGRESQL_PASSWORD secret>
```

---

## 4.5 — Troubleshooting the pipeline

The diagnostics section of the playbook captures and prints:

- All container states (`docker ps`)
- `haven-authentik-db-1` logs
- `haven-authentik-worker-1` logs (last 100 lines)
- `haven-authentik-server-1` logs (last 50 lines)
- `haven-infisical-db-1` logs
- Caddy logs (last 200 lines)
- Infisical app logs (last 80 lines)
- HTTP check on port 80
- TLS certificate issuer + expiry for all 3 domains

**Common failure modes:**

| Symptom | Cause | Fix |
|---------|-------|-----|
| Worker `Restarting (1)` | `PermissionError: '/media/public'` | Media dir not owned by uid 1000 — already fixed in playbook |
| `authentik-core.sock` error in browser | Server gunicorn crashed / not yet ready | Wait 2 min after pipeline, or run pipeline again (triggers restart) |
| Caddy gets staging cert instead of production | DNSSEC broken → ACME fails → fallback | Fix DNSSEC (Phase 1), delete staging certs, restart Caddy |
| `INFISICAL_ENCRYPTION_KEY` error | Key is 64 chars instead of 32 | Regenerate with `token_hex(16)` — exactly 32 chars |
| Infisical `connect ECONNREFUSED 127.0.0.1:587` | SMTP not configured | Cosmetic — email features disabled, services still work |

---

## 4.6 — Verify

After pipeline completes successfully (`ok=32, failed=0`):

```powershell
# All should return HTTP 308 (redirect to HTTPS) or 200
curl -I http://auth.huybrechts.xyz
curl -I http://vault.huybrechts.xyz
curl -I http://secrets.huybrechts.xyz

# TLS certificates should be from Let's Encrypt (not staging)
$domains = @("auth","vault","secrets") | ForEach-Object { "$_.huybrechts.xyz" }
foreach ($d in $domains) {
    $cert = (Invoke-WebRequest "https://$d" -SkipCertificateCheck 2>$null)
    Write-Host "$d : $(($cert.RawContent | Select-String 'Let').Matches.Value)"
}
```

---

## Checklist

- [ ] Pipeline runs without `failed` tasks
- [ ] All 9 containers show `Up` (not `Restarting`)
- [ ] `haven-authentik-worker-1` shows `Up` with `health: starting` or `(healthy)`
- [ ] TLS certs obtained from Let's Encrypt production (not staging)
- [ ] `https://auth.huybrechts.xyz` shows Authentik login page
- [ ] `https://vault.huybrechts.xyz` shows Vaultwarden web vault
- [ ] `https://secrets.huybrechts.xyz` shows Infisical login/welcome page
