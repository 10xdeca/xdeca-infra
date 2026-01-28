#!/bin/bash
# Unified backup script for all services
# Backs up to AWS S3 via rclone
# Usage: ./backup.sh [all|openproject]

set -e

SERVICE=${1:-all}
BACKUP_DIR="/tmp/backups"
DATE=$(date +%Y-%m-%d)
RCLONE_REMOTE="s3"
BUCKET="xdeca-backups"
RETENTION_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

backup_openproject() {
  log "Backing up OpenProject..."

  local backup_file="$BACKUP_DIR/openproject-$DATE.sql.gz"

  # Dump PostgreSQL (OpenProject uses internal postgres, must run as postgres user)
  docker exec -u postgres openproject_openproject_1 \
    pg_dump openproject | gzip > "$backup_file"

  # Upload to object storage
  rclone copy "$backup_file" "$RCLONE_REMOTE:$BUCKET/openproject/"

  log "OpenProject backup complete: openproject-$DATE.sql.gz"
}

cleanup_old_backups() {
  log "Cleaning up backups older than $RETENTION_DAYS days..."

  # Clean local temp backups
  find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

  # Clean remote backups (rclone delete with min-age)
  rclone delete "$RCLONE_REMOTE:$BUCKET/openproject/" \
    --min-age "${RETENTION_DAYS}d" 2>/dev/null || true

  log "Cleanup complete"
}

# Run backups
case $SERVICE in
  all)
    backup_openproject
    cleanup_old_backups
    ;;
  openproject)
    backup_openproject
    ;;
  cleanup)
    cleanup_old_backups
    ;;
  *)
    echo "Usage: $0 [all|openproject|cleanup]"
    exit 1
    ;;
esac

log "Backup complete!"
