# Backups

Automated backups to Google Cloud Storage.

## Overview

| Service | What | Schedule | Retention |
|---------|------|----------|-----------|
| Kan.bn | PostgreSQL | Daily 4 AM | 7 days |
| Outline | PostgreSQL | Daily 4 AM | 7 days |

## Setup

### 1. Create and Encrypt Secrets

```bash
cd backups
cp secrets.yaml.example secrets.yaml
# Edit with your values
sops -e -i secrets.yaml
```

### 2. Deploy

```bash
./scripts/deploy-to.sh <ip> backups
```

This will:
- Deploy rclone config (GCS via GCE service account)
- Create the backup bucket (if it doesn't exist)
- Deploy backup/restore scripts
- Set up daily cron job

## Manual Operations

### Run Backup

```bash
ssh ubuntu@34.116.110.7
/opt/scripts/backup.sh all
```

### List Remote Backups

```bash
rclone ls gcs:xdeca-backups/
rclone ls gcs:xdeca-backups/kanbn/
rclone ls gcs:xdeca-backups/outline/
```

### Restore

```bash
# Latest
/opt/scripts/restore.sh kanbn
/opt/scripts/restore.sh outline

# Specific date
/opt/scripts/restore.sh kanbn 2024-01-15
/opt/scripts/restore.sh outline 2024-01-15
```

See `docs/backups.md` for full restore procedures.

## Files

| File | Purpose |
|------|---------|
| `secrets.yaml` | GCS configuration (encrypted) |
| `scripts/backup.sh` | Backup script |
| `scripts/restore.sh` | Restore script |
