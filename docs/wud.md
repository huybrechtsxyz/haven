# WUD (What's Up Docker) for Haven

[Back to Guide](./GUIDE.md#setup-wud)

## Overview

WUD (What's Up Docker) is a self-hosted status dashboard for monitoring the health and status of your Docker containers. It provides a simple and intuitive interface to view the status of all your containers, including their uptime, resource usage, and logs. WUD helps you keep track of your Docker environment and quickly identify any issues or failures.

## Initial Setup

The initial setup of WUD involves deploying the WUD container, configuring access to your Docker environment, and setting up authentication for secure access.

1. Log in to `https://wud.huybrechts.xyz` with the admin credentials set during initial setup
2. Store credentials in Vaultwarden under "WUD Admin"
3. Configure WUD to connect to the Docker environment (usually via a Unix socket or TCP)
4. Test the connection and ensure WUD can retrieve container information
5. Set up authentication (e.g. via Authentik SSO) for secure access
6. Explore the WUD dashboard and familiarize yourself with the available metrics and logs
7. Set up alerts or notifications for critical container events (optional)

## Monitoring and Maintenance

Regularly check the WUD dashboard to monitor the health and status of your Docker containers. Use the logs and metrics provided by WUD to troubleshoot any issues or failures that may arise. Keep WUD updated to benefit from new features and security patches.

1. Regularly log in to the WUD dashboard to monitor container status
2. Use the logs and metrics to identify and troubleshoot issues
3. Keep WUD updated to ensure you have the latest features and security patches
4. Consider setting up alerts or notifications for critical events (e.g. container crashes, high resource usage) to proactively manage your Docker environment.
