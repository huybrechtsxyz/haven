# Portainer for Haven

[Back to Guide](./GUIDE.md#setup-portainer)

## Overview

Portainer is a lightweight, open-source container management platform that provides a user-friendly interface for managing Docker environments. It allows you to easily deploy, manage, and monitor your Docker containers, images, networks, and volumes. Portainer simplifies container orchestration and provides features like role-based access control, application templates, and real-time container logs.

## Initial Setup

The initial setup of Portainer involves deploying the Portainer container, creating an admin account, and configuring access to your Docker environment.

1. Log in to `https://portainer.huybrechts.xyz` with the admin credentials set during initial setup
2. Store credentials in Vaultwarden under "Portainer Admin"

> **No SSO** — Portainer CE does not support OAuth/OIDC. That feature requires Portainer Business Edition (BE). The free BE tier covers up to 3 nodes and 5 users — upgrade later via Settings → Licenses if SSO becomes a priority.

When upgrading to BE, the Authentik OAuth config to use is:

> - Authorization URL: `https://auth.huybrechts.xyz/application/o/authorize/`
> - Access Token URL: `https://auth.huybrechts.xyz/application/o/token/`
> - Resource URL: `https://auth.huybrechts.xyz/application/o/userinfo/`
> - Client ID: `portainer` — add this provider back to the blueprint and run `run_config=true`
