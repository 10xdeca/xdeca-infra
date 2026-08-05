# Backup & Restore

All services backup to **GitHub** (10xdeca/xdeca-backups).

## Overview

| Service | What's Backed Up | Schedule | Retention |
|---------|------------------|----------|-----------|
| Kan.bn | PostgreSQL database | Daily 4 AM | 7 days |
| Outline | PostgreSQL database | Daily 4 AM | 7 days |
| Outline/Kan.bn MinIO | Object store volume (ATTACHMENTS for both) | Daily 4 AM | 7 days |
| Radicale | CalDAV/CardDAV collections | Daily 4 AM | 7 days |
| Gremlin | SQLite database | Daily 4 AM | 7 days |

> **Why MinIO is a separate line.** Outline and Kan.bn keep document/card text in
> Postgres but **attachments (uploaded files) in MinIO**. Backing up only Postgres
> means a restore silently orphans every attachment — the text survives, the files
> behind it 404. The `outline_minio` job tars the raw `outline_minio_data` volume
> (objects are KMS-encrypted at rest, so the encrypted backend is captured as-is and
> must be restored with the unchanged KMS key from the deploy secrets).

## Manual Operations

### Run Backup Now

```bash
# All services
/opt/scripts/backup.sh all

# Single service
/opt/scripts/backup.sh kanbn
/opt/scripts/backup.sh outline
/opt/scripts/backup.sh outline_minio   # MinIO object store (Outline + Kan.bn attachments)
/opt/scripts/backup.sh radicale
/opt/scripts/backup.sh gremlin
```

### Check Backup Logs

```bash
tail -f /var/log/backup.log
```

## Restore

### Manual Restore

```bash
# Restore latest backup (pulls from GitHub)
/opt/scripts/restore.sh kanbn
/opt/scripts/restore.sh outline
/opt/scripts/restore.sh radicale
/opt/scripts/restore.sh gremlin
```

### Restore Process

1. Script clones backup repo from GitHub (shallow)
2. Stops the service
3. Drops and recreates database (or restores files)
4. Restores PostgreSQL dump (or tar archive)
5. Restarts the service

## Backup Files in GitHub Repo

| Service | File | Contents |
|---------|------|----------|
| Kan.bn | `kanbn.sql` | Decompressed PostgreSQL dump |
| Outline | `outline.sql` | Decompressed PostgreSQL dump |
| Outline/Kan.bn MinIO | `outline_minio.tar` | Decompressed `outline_minio_data` volume (attachments) |
| Radicale | `radicale.tar` | Decompressed collections archive |
| Gremlin | `gremlin.db` | SQLite database |

Files are stored decompressed so git deltas work efficiently.

### Restoring the MinIO object store (manual — no `restore.sh` path yet)

`restore.sh` does not yet handle `outline_minio`. To restore attachments from
`outline_minio.tar`:

```bash
# 1. Stop the MinIO container (and Outline, to avoid writes mid-restore)
cd ~/apps/outline && docker compose stop outline minio
# 2. Replace the volume contents from the backup tar
docker run --rm -v outline_minio_data:/data -v "$PWD":/backup alpine \
  sh -c 'rm -rf /data/* && tar xzf /backup/outline_minio.tar -C / '
# 3. Bring the stack back up (KMS key comes from the unchanged deploy secrets)
docker compose up -d
```

> Note: the tar carries the KMS-encrypted backend. Restore only decrypts if the
> running MinIO still has the same `MINIO_KMS_SECRET_KEY_FILE` value it had when the
> backup was taken — that key lives in the SOPS-encrypted deploy secrets, so keep it
> stable. Automating this into `restore.sh` is a follow-up.

## Troubleshooting

### Backup not running?

```bash
# Check cron
cat /etc/cron.d/backup

# Check logs
tail -50 /var/log/backup.log
```

### GitHub push failing?

```bash
# Test deploy key
ssh -T git@github-backups

# Check key exists
ls -la ~/.ssh/xdeca-backups-deploy
```
