#!/bin/bash
# Restore script for all services
# Restores from GitHub backup repo (10xdeca/xdeca-backups)
# Usage: ./restore.sh <service>
#   service: kanbn, outline, radicale, gremlin, minio

set -e

SERVICE=$1
RESTORE_DIR="/tmp/restore"
GITHUB_BACKUP_REPO="git@github-backups:10xdeca/xdeca-backups.git"
BACKUP_CLONE_DIR="$RESTORE_DIR/xdeca-backups"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2; }

if [ -z "$SERVICE" ]; then
  echo "Usage: $0 <service>"
  echo "  service: kanbn, outline, radicale, gremlin, minio"
  echo ""
  echo "Examples:"
  echo "  $0 kanbn    # Restore latest from GitHub backup"
  echo "  $0 outline  # Restore latest from GitHub backup"
  exit 1
fi

mkdir -p "$RESTORE_DIR"

# Clone the backup repo (shallow) to get latest backups
fetch_backups() {
  log "Fetching backups from GitHub..."
  rm -rf "$BACKUP_CLONE_DIR"
  git clone --depth 1 "$GITHUB_BACKUP_REPO" "$BACKUP_CLONE_DIR"
}

cleanup_backups() {
  rm -rf "$BACKUP_CLONE_DIR"
}

restore_kanbn() {
  log "Restoring Kan.bn..."

  fetch_backups

  # backup.sh stores decompressed SQL for better git deltas
  local BACKUP_FILE="$BACKUP_CLONE_DIR/kanbn.sql"
  if [ ! -f "$BACKUP_FILE" ]; then
    error "No kanbn.sql found in backup repo"
    cleanup_backups
    exit 1
  fi

  # Ensure Kan.bn postgres is running
  cd ~/apps/xdeca-kanbn
  docker compose up -d postgres
  log "Waiting for PostgreSQL to start..."
  sleep 10

  # Drop and recreate database
  log "Dropping existing database..."
  docker exec -i kanbn_postgres bash -c "psql -U kanbn -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'kanbn' AND pid <> pg_backend_pid();\" postgres && dropdb -U kanbn kanbn && createdb -U kanbn kanbn"

  # Restore database
  log "Restoring database..."
  docker exec -i kanbn_postgres psql -U kanbn kanbn < "$BACKUP_FILE"

  log "Restarting Kan.bn..."
  docker compose restart

  cleanup_backups
  log "Kan.bn restore complete!"
}

restore_outline() {
  log "Restoring Outline..."

  fetch_backups

  local BACKUP_FILE="$BACKUP_CLONE_DIR/outline.sql"
  if [ ! -f "$BACKUP_FILE" ]; then
    error "No outline.sql found in backup repo"
    cleanup_backups
    exit 1
  fi

  # Ensure Outline postgres is running
  cd ~/apps/xdeca-outline
  docker compose up -d postgres
  log "Waiting for PostgreSQL to start..."
  sleep 10

  # Drop and recreate database
  log "Dropping existing database..."
  docker exec -i outline_postgres bash -c "psql -U outline -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'outline' AND pid <> pg_backend_pid();\" postgres && dropdb -U outline outline && createdb -U outline outline"

  # Restore database
  log "Restoring database..."
  docker exec -i outline_postgres psql -U outline outline < "$BACKUP_FILE"

  log "Restarting Outline..."
  docker compose restart

  cleanup_backups
  log "Outline restore complete!"
}

restore_gremlin() {
  log "Restoring gremlin..."

  fetch_backups

  local BACKUP_FILE="$BACKUP_CLONE_DIR/gremlin.db"
  if [ ! -f "$BACKUP_FILE" ]; then
    error "No gremlin.db found in backup repo"
    cleanup_backups
    exit 1
  fi

  # Copy SQLite database into container volume
  log "Restoring database..."
  docker cp "$BACKUP_FILE" gremlin:/app/data/gremlin.db

  log "Restarting gremlin..."
  cd ~/apps/xdeca-gremlin
  docker compose restart

  cleanup_backups
  log "gremlin restore complete!"
}

restore_minio() {
  log "Restoring MinIO buckets..."

  # MinIO backups live on the 'minio' branch (force-pushed, no history)
  log "Fetching MinIO backup from GitHub (minio branch)..."
  rm -rf "$BACKUP_CLONE_DIR"
  git clone --depth 1 --branch minio "$GITHUB_BACKUP_REPO" "$BACKUP_CLONE_DIR"

  local BACKUP_FILE="$BACKUP_CLONE_DIR/minio.tar"
  if [ ! -f "$BACKUP_FILE" ]; then
    error "No minio.tar found in backup repo"
    cleanup_backups
    exit 1
  fi

  # Stop MinIO to avoid conflicts during restore
  log "Stopping MinIO..."
  cd ~/apps/xdeca-outline
  docker compose stop minio

  # Restore bucket data into the MinIO volume
  # Copies into /data, preserving bucket directory structure
  log "Restoring bucket data..."
  docker compose run --rm --entrypoint sh \
    -v "$BACKUP_FILE:/restore.tar:ro" minio \
    -c "tar xf /restore.tar -C /data"

  # Start MinIO
  log "Starting MinIO..."
  docker compose up -d minio

  cleanup_backups
  log "MinIO restore complete!"
}

restore_radicale() {
  log "Restoring Radicale..."

  fetch_backups

  local BACKUP_DIR_RAD="$BACKUP_CLONE_DIR/radicale"
  if [ ! -d "$BACKUP_DIR_RAD" ]; then
    # Fall back to legacy tar format
    local BACKUP_FILE="$BACKUP_CLONE_DIR/radicale.tar"
    if [ ! -f "$BACKUP_FILE" ]; then
      error "No radicale/ directory or radicale.tar found in backup repo"
      cleanup_backups
      exit 1
    fi
    log "Restoring from legacy tar format..."
    BACKUP_DIR_RAD="$RESTORE_DIR/radicale-extracted"
    mkdir -p "$BACKUP_DIR_RAD"
    tar xf "$BACKUP_FILE" -C "$BACKUP_DIR_RAD"
  fi

  # Stop Radicale
  log "Stopping Radicale..."
  cd ~/apps/xdeca-radicale
  docker compose stop radicale

  # Restore collections into the container volume
  log "Restoring collections..."
  docker cp "$BACKUP_DIR_RAD/." radicale:/data/collections/

  # Start Radicale
  log "Starting Radicale..."
  docker compose up -d

  cleanup_backups
  log "Radicale restore complete!"
}

# Run restore
case $SERVICE in
  kanbn)
    restore_kanbn
    ;;
  outline)
    restore_outline
    ;;
  radicale)
    restore_radicale
    ;;
  gremlin)
    restore_gremlin
    ;;
  minio)
    restore_minio
    ;;
  *)
    error "Unknown service: $SERVICE"
    echo "Valid services: kanbn, outline, radicale, gremlin, minio"
    exit 1
    ;;
esac
