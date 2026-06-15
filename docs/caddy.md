# Caddy for Haven

[Back to Guide](./guide.md#hearth-service-configuration)

## Overview

Caddy is a powerful, open-source web server and reverse proxy that serves as the entry point for all incoming HTTP/HTTPS traffic to the haven platform. It handles TLS termination, routing, and load balancing for the various services running on the hearth VPS. Caddy's automatic HTTPS feature simplifies TLS certificate management, while its flexible configuration allows us to route traffic to different services based on subdomains.

## Caddy Configuration

Caddy is configured using a `Caddyfile` located in the `deploy/ansible-init/files/caddy/Caddyfile` path. The Caddyfile defines the routing rules for incoming requests, directing them to the appropriate backend services based on the requested hostname. For example, requests to `auth.huybrechts.xyz` are routed to the Authentik service, while requests to `vault.huybrechts.xyz` are routed to the Vaultwarden service.

