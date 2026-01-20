# Discourse Backup & Restore

Backups are stored in **Oracle Cloud Object Storage** (Archive tier) for lowest cost.

## Cost

- **First 10GB: Free** (Oracle Always Free tier)
- After 10GB: ~$0.0026/GB/month
- Typical Discourse backup: 100MB-500MB

## How It Works

```
Discourse (3 AM) → Local backup → rclone (4 AM) → Oracle Archive Storage
```

1. Discourse creates automatic daily backups at 3 AM
2. Cron job syncs backups to Oracle at 4 AM via rclone
3. Only keeps 2 local backups to save disk space

## Setup

Run on the VPS after Discourse is installed:

```bash
./scripts/setup-discourse-backup.sh
```

The script will:
1. Install rclone
2. Guide you through creating OCI credentials
3. Create the backup bucket (Archive tier)
4. Set up daily cron job

### Prerequisites

- OCI CLI configured on VPS
- Customer Secret Keys for S3-compatible access (script guides you)

## Daily Operations

| Task | Command |
|------|---------|
| List remote backups | `rclone ls oci-archive:discourse-backups` |
| Manual sync | `sudo /opt/scripts/sync-discourse-backups.sh` |
| Check sync logs | `tail -f /var/log/discourse-backup-sync.log` |

## Restore Process

Archive-tier storage requires a 2-step restore (~1 hour wait):

```bash
sudo /opt/scripts/restore-discourse-backup.sh
```

### Manual Restore Steps

1. **List available backups**
   ```bash
   rclone ls oci-archive:discourse-backups
   ```

2. **Request object restore** (moves from cold → hot storage)
   ```bash
   oci os object restore \
     --namespace nickmeinhold \
     --bucket-name discourse-backups \
     --name "discourse-2024-01-15.tar.gz" \
     --hours 24
   ```

3. **Check status** (wait for "Available", ~1 hour)
   ```bash
   oci os object head \
     --namespace nickmeinhold \
     --bucket-name discourse-backups \
     --name "discourse-2024-01-15.tar.gz" | grep archival-state
   ```
   
   Status meanings:
   - `Archived` - Still in cold storage
   - `Restoring` - Retrieval in progress
   - `Available` - Ready to download

4. **Download backup**
   ```bash
   rclone copy oci-archive:discourse-backups/discourse-2024-01-15.tar.gz \
     /var/discourse/shared/standalone/backups/default/
   ```

5. **Restore in Discourse**
   
   Option A - Admin UI:
   - Go to Admin → Backups
   - Click "Restore" on the backup
   
   Option B - Command line:
   ```bash
   cd /var/discourse
   ./launcher enter app
   discourse restore discourse-2024-01-15.tar.gz
   exit
   ./launcher rebuild app
   ```

## Discourse Backup Settings

Configure in Admin → Settings → Backups:

| Setting | Value |
|---------|-------|
| backup_frequency | 1 (daily) |
| maximum_backups | 2 |
| backup_time_of_day | 3 (3 AM) |
| include_uploads_in_backups | true |

## Troubleshooting

**Sync not running?**
```bash
crontab -l | grep discourse
```

**rclone connection issues?**
```bash
rclone lsd oci-archive:
```

**Check credentials:**
```bash
cat ~/.config/rclone/rclone.conf
```
