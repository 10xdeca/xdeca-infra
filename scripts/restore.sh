#!/bin/bash
# Restore script for all services
# Restores from AWS S3 via rclone
# Usage: ./restore.sh <service> [date]
#   service: openproject
#   date: YYYY-MM-DD (optional, defaults to latest)

set -e

SERVICE=$1
DATE=${2:-""}
RESTORE_DIR="/tmp/restore"
RCLONE_REMOTE="s3"
BUCKET="xdeca-backups"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2; }

if [ -z "$SERVICE" ]; then
  echo "Usage: $0 <service> [date]"
  echo "  service: openproject"
  echo "  date: YYYY-MM-DD (optional)"
  echo ""
  echo "Examples:"
  echo "  $0 openproject           # Restore latest"
  echo "  $0 openproject 2024-01-15 # Restore specific date"
  exit 1
fi

mkdir -p "$RESTORE_DIR"

list_backups() {
  local service=$1
  log "Available backups for $service:"
  rclone ls "$RCLONE_REMOTE:$BUCKET/$service/" | sort -r | head -20
}

restore_openproject() {
  log "Restoring OpenProject..."

  # Find backup file
  if [ -n "$DATE" ]; then
    BACKUP_FILE="openproject-$DATE.sql.gz"
  else
    BACKUP_FILE=$(rclone ls "$RCLONE_REMOTE:$BUCKET/openproject/" | sort -r | head -1 | awk '{print $2}')
  fi

  if [ -z "$BACKUP_FILE" ]; then
    error "No backup found"
    list_backups openproject
    exit 1
  fi

  log "Restoring from: $BACKUP_FILE"

  # Download backup
  log "Downloading backup from S3..."
  rclone copy "$RCLONE_REMOTE:$BUCKET/openproject/$BACKUP_FILE" "$RESTORE_DIR/"

  # Ensure OpenProject is running (need postgres)
  cd ~/apps/openproject
  docker-compose up -d
  log "Waiting for PostgreSQL to start..."
  sleep 30

  # Drop and recreate database
  log "Dropping existing database..."
  docker exec -i -u postgres openproject_openproject_1 bash -c "psql -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'openproject' AND pid <> pg_backend_pid();\" && dropdb openproject && createdb openproject"

  # Restore database
  log "Restoring database..."
  gunzip -c "$RESTORE_DIR/$BACKUP_FILE" | \
    docker exec -i -u postgres openproject_openproject_1 psql openproject

  log "Restarting OpenProject..."
  docker-compose restart

  # Cleanup
  rm -f "$RESTORE_DIR/$BACKUP_FILE"

  log "OpenProject restore complete!"
}

# Run restore
case $SERVICE in
  openproject)
    restore_openproject
    ;;
  list)
    list_backups "${DATE:-openproject}"
    ;;
  *)
    error "Unknown service: $SERVICE"
    echo "Valid services: openproject, list"
    exit 1
    ;;
esac
