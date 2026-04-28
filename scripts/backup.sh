#!/bin/bash
# Unified backup script for all services
# Dumps databases/data, pushes to GitHub (10xdeca/xdeca-backups)
# Usage: ./backup.sh [all|kanbn|outline|radicale]

SERVICE=${1:-all}
BACKUP_DIR="/tmp/backups"
DATE=$(date +%Y-%m-%d)
RETENTION_DAYS=7
FAILED_SERVICES=()

# GitHub backup config
GITHUB_BACKUP_REPO="git@github-backups:10xdeca/xdeca-backups.git"
GITHUB_BACKUP_DIR="/tmp/xdeca-backups"
GITHUB_REPO_SIZE_ALERT_MB=500

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

send_telegram_alert() {
  local message="$1"
  if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    log "Telegram alert skipped (TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set)"
    return 0
  fi
  local -a args=(
    -s -X POST
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    -d "chat_id=$TELEGRAM_CHAT_ID"
    -d "parse_mode=HTML"
    --data-urlencode "text=$message"
  )
  if [ -n "$TELEGRAM_THREAD_ID" ]; then
    args+=(-d "message_thread_id=$TELEGRAM_THREAD_ID")
  fi
  curl "${args[@]}" > /dev/null 2>&1 || true
}

check_repo_size() {
  if [ ! -d "$GITHUB_BACKUP_DIR" ]; then
    return 0
  fi
  local size_mb
  size_mb=$(du -sm "$GITHUB_BACKUP_DIR" --exclude='.git' 2>/dev/null | awk '{print $1}')
  if [ -z "$size_mb" ]; then
    return 0
  fi
  if [ "$size_mb" -gt "$GITHUB_REPO_SIZE_ALERT_MB" ]; then
    log "GitHub backup payload is ${size_mb} MB (threshold: ${GITHUB_REPO_SIZE_ALERT_MB} MB)"
    send_telegram_alert "$(printf '<b>Backup Size Alert</b>\nGitHub backup payload: %s MB (threshold: %s MB)\nConsider pruning old data or increasing the threshold.' "$size_mb" "$GITHUB_REPO_SIZE_ALERT_MB")"
  fi
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

backup_kanbn() {
  log "Backing up Kan.bn..."

  local backup_file="$BACKUP_DIR/kanbn-$DATE.sql.gz"

  # Dump PostgreSQL
  docker exec kanbn_postgres \
    pg_dump -U kanbn kanbn | gzip > "$backup_file"

  log "Kan.bn backup complete: kanbn-$DATE.sql.gz"
}

backup_outline() {
  log "Backing up Outline..."

  local backup_file="$BACKUP_DIR/outline-$DATE.sql.gz"

  # Dump PostgreSQL
  docker exec outline_postgres \
    pg_dump -U outline outline | gzip > "$backup_file"

  log "Outline backup complete: outline-$DATE.sql.gz"
}

backup_radicale() {
  log "Backing up Radicale..."

  local backup_file="$BACKUP_DIR/radicale-$DATE.tar.gz"

  # Tar the collections from the Docker volume
  docker exec radicale tar czf - /data/collections > "$backup_file"

  log "Radicale backup complete: radicale-$DATE.tar.gz"
}

backup_gremlin() {
  log "Backing up gremlin..."

  local backup_file="$BACKUP_DIR/gremlin-$DATE.db"

  # Copy SQLite database from local container volume
  docker cp gremlin:/app/data/gremlin.db "$backup_file" || {
    error "Failed to docker cp gremlin.db — is the container running?"
    return 1
  }

  if [ ! -s "$backup_file" ]; then
    error "gremlin.db backup file is empty"
    return 1
  fi

  log "gremlin backup complete: gremlin-$DATE.db"
}

backup_to_github() {
  local services=("$@")

  # Check prerequisites
  if ! command -v git &> /dev/null; then
    error "git not installed, skipping GitHub backup"
    return 0
  fi
  if [ ! -f "$HOME/.ssh/xdeca-backups-deploy" ]; then
    error "Deploy key not found at ~/.ssh/xdeca-backups-deploy, skipping GitHub backup"
    return 0
  fi

  log "Pushing backups to GitHub..."

  # Clone or pull the backup repo (shallow)
  if [ -d "$GITHUB_BACKUP_DIR/.git" ]; then
    git -C "$GITHUB_BACKUP_DIR" pull --rebase 2>/dev/null || {
      rm -rf "$GITHUB_BACKUP_DIR"
      git clone --depth 1 "$GITHUB_BACKUP_REPO" "$GITHUB_BACKUP_DIR"
    }
  else
    rm -rf "$GITHUB_BACKUP_DIR"
    git clone --depth 1 "$GITHUB_BACKUP_REPO" "$GITHUB_BACKUP_DIR" 2>/dev/null || {
      # First push — repo may be empty
      mkdir -p "$GITHUB_BACKUP_DIR"
      git -C "$GITHUB_BACKUP_DIR" init -b main
      git -C "$GITHUB_BACKUP_DIR" remote add origin "$GITHUB_BACKUP_REPO"
    }
  fi

  # Copy each service dump, decompressing so git deltas work
  for svc in "${services[@]}"; do
    local dump
    dump=$(find "$BACKUP_DIR" -name "${svc}-${DATE}.*" -type f 2>/dev/null | head -1)

    if [ -z "$dump" ] || [ ! -f "$dump" ]; then
      error "Dump file not found for $svc (expected ${svc}-${DATE}.*)"
      continue
    fi

    case "$dump" in
      *.sql.gz)
        gunzip -c "$dump" > "$GITHUB_BACKUP_DIR/${svc}.sql"
        log "Decompressed $svc backup → ${svc}.sql"
        ;;
      *.tar.gz)
        gunzip -c "$dump" > "$GITHUB_BACKUP_DIR/${svc}.tar"
        log "Decompressed $svc backup → ${svc}.tar"
        ;;
      *)
        local ext="${dump##*.}"
        cp "$dump" "$GITHUB_BACKUP_DIR/${svc}.${ext}"
        log "Copied $svc backup → ${svc}.${ext}"
        ;;
    esac
  done

  # Commit and push
  git -C "$GITHUB_BACKUP_DIR" add -A
  if git -C "$GITHUB_BACKUP_DIR" diff --cached --quiet; then
    log "No changes to push to GitHub"
  else
    git -C "$GITHUB_BACKUP_DIR" \
      -c user.name="xdeca-backup" \
      -c user.email="backup@xdeca.com" \
      commit -m "backup $DATE"
    git -C "$GITHUB_BACKUP_DIR" push origin HEAD 2>/dev/null || \
      git -C "$GITHUB_BACKUP_DIR" push --set-upstream origin main
    log "Backups pushed to GitHub"
  fi

  check_repo_size
}

cleanup_old_backups() {
  log "Cleaning up local backups older than $RETENTION_DAYS days..."
  find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
  log "Cleanup complete"
}

# Run backups
case $SERVICE in
  all)
    SUCCEEDED=()
    # gremlin omitted: hibernating since 2026-04-27 (no container to back up).
    # Re-add when waking gremlin per gremlin/CLAUDE.md wake-up runbook.
    for svc in kanbn outline radicale; do
      if "backup_${svc}"; then
        SUCCEEDED+=("$svc")
      else
        error "$svc backup failed"
        FAILED_SERVICES+=("$svc")
      fi
    done
    if [ ${#SUCCEEDED[@]} -gt 0 ]; then
      backup_to_github "${SUCCEEDED[@]}"
    fi
    cleanup_old_backups
    ;;
  kanbn)
    backup_kanbn && backup_to_github kanbn || FAILED_SERVICES+=(kanbn)
    ;;
  outline)
    backup_outline && backup_to_github outline || FAILED_SERVICES+=(outline)
    ;;
  radicale)
    backup_radicale && backup_to_github radicale || FAILED_SERVICES+=(radicale)
    ;;
  gremlin)
    backup_gremlin && backup_to_github gremlin || FAILED_SERVICES+=(gremlin)
    ;;
  cleanup)
    cleanup_old_backups
    ;;
  *)
    echo "Usage: $0 [all|kanbn|outline|radicale|gremlin|cleanup]"
    exit 1
    ;;
esac

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
  error "Backups failed for: ${FAILED_SERVICES[*]}"
  send_telegram_alert "$(printf '<b>Backup Failure</b>\nFailed services: %s\nDate: %s' "${FAILED_SERVICES[*]}" "$DATE")"
  exit 1
fi

log "Backup complete!"
