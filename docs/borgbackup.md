# BorgBackup for Haven

[Back to Guide](./GUIDE.md#setup-borgbackup)

## Overview

BorgBackup is a powerful deduplicating backup tool that efficiently stores and manages backups. It supports compression, encryption, and remote repositories, making it ideal for secure and space-efficient backups.

## Initial Setup

BorgBackup backs up critical data to the Hetzner Storage Box with `repokey-blake2` encryption, daily at 02:00 UTC.

- **Target:** `<STORAGEBOX_SUBACCOUNT>@<STORAGEBOX_HOST>:./hearth` (SSH port 23)
- **Data:** Authentik, Vaultwarden, Infisical volumes + `/opt/haven/etc`
- **Retention:** 7 daily, 4 weekly, 6 monthly
- **Log:** `/var/log/haven-backup.log`

### Step 1 — Generate SSH key and initialise repository

Add the `HETZNER_STORAGEBOX_PASSWORD` secret (the sub-account password from Hetzner Robot) to GitHub Environment Secrets.

Run pipeline with `run_init: true`, `configure_borg: true`, `run_config: false`, `run_deploy: false`.

The pipeline will automatically:

1. Generate an ed25519 SSH key pair on the VPS (`/opt/haven/.ssh/borg_ed25519`)
2. Upload the public key to the Storage Box using Hetzner's `install-ssh-key` command (requires `STORAGEBOX_PASSWORD`)
3. Scan the Storage Box host key and add it to `known_hosts`
4. Initialise the BorgBackup repository with `repokey-blake2` encryption
5. Export and display the repository key

> **How SSH key upload works:** Hetzner Storage Boxes require SSH keys to be uploaded via the `install-ssh-key` SSH command — the Robot web UI does not support this for port 23 access. The pipeline automates this using `sshpass` with the sub-account password. See [Hetzner docs: Add SSH keys](https://docs.hetzner.com/storage/storage-box/backup-space-ssh-keys/) for details.

### Step 2 — Save the repository key

In the workflow log → task **"Show BorgBackup repokey"** → copy the key block and save to Vaultwarden as **"Haven BorgBackup repo key"**.

> ⚠️ Without this key + the passphrase, backups **cannot** be restored.
>
> The repokey is also displayed on every `run_config` run (when `configure_borg: true`), so you can retrieve it later without re-running init.

### Step 3 — Enable automated backups

In `deploy/ansible-config/vars/main.yml`:

```yaml
configure_borg: true
```

Commit and push, then run pipeline with `run_config: true`. The backup script and daily cron job are now active.

## Subsequent Deploys

For routine updates (code changes, image updates):

| Input                  | Value  | Notes                                           |
| ---------------------- | ------ | ----------------------------------------------- |
| `run_config`           | `true` | Enforce system config, correct any drift        |
| `run_deploy`           | `true` | Pull latest images, recreate changed containers |
| `backup_before_deploy` | `true` | Optional — snapshot data before deploying       |
| `dry_run`              | `true` | Optional — plan only, no changes applied        |
