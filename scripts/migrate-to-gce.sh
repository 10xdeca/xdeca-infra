#!/bin/bash
# One-time migration from AWS Lightsail to GCP Compute Engine
# Usage: ./scripts/migrate-to-gce.sh <lightsail-ip> <gce-ip>
#
# Steps:
# 1. Dump PostgreSQL databases on Lightsail (Kan.bn + Outline)
# 2. SCP dumps from Lightsail → local → GCE
# 3. Deploy all services to GCE via deploy-to.sh
# 4. Restore databases on GCE
# 5. Sync MinIO data between instances
# 6. Run verification checks

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <lightsail-ip> <gce-ip>"
    echo "  lightsail-ip: Source server (e.g. 13.54.159.183)"
    echo "  gce-ip:       Destination GCE instance (e.g. 34.116.110.7)"
    exit 1
fi

LIGHTSAIL_IP=$1
GCE_IP=$2
LIGHTSAIL="ubuntu@$LIGHTSAIL_IP"
GCE="ubuntu@$GCE_IP"
LOCAL_DUMP_DIR="/tmp/xdeca-migration"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATE=$(date +%Y-%m-%d-%H%M%S)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()   { echo -e "${GREEN}[MIGRATE]${NC} $1"; }
warn()  { echo -e "${YELLOW}[MIGRATE]${NC} $1"; }
error() { echo -e "${RED}[MIGRATE]${NC} $1" >&2; }

# ── Pre-flight checks ──────────────────────────────────────────────

log "Pre-flight checks..."

log "Testing SSH to Lightsail ($LIGHTSAIL_IP)..."
if ! ssh -o ConnectTimeout=5 "$LIGHTSAIL" "echo ok" > /dev/null 2>&1; then
    error "Cannot SSH to Lightsail ($LIGHTSAIL_IP)"
    exit 1
fi

log "Testing SSH to GCE ($GCE_IP)..."
if ! ssh -o ConnectTimeout=5 "$GCE" "echo ok" > /dev/null 2>&1; then
    error "Cannot SSH to GCE ($GCE_IP)"
    exit 1
fi

mkdir -p "$LOCAL_DUMP_DIR"

# ── Step 1: Dump databases on Lightsail ────────────────────────────

log "Step 1: Dumping databases on Lightsail..."

log "Dumping Kan.bn PostgreSQL..."
ssh "$LIGHTSAIL" "docker exec kanbn_postgres pg_dump -U kanbn kanbn | gzip > /tmp/kanbn-migrate-$DATE.sql.gz"

log "Dumping Outline PostgreSQL..."
ssh "$LIGHTSAIL" "docker exec outline_postgres pg_dump -U outline outline | gzip > /tmp/outline-migrate-$DATE.sql.gz"

# ── Step 2: Transfer dumps Lightsail → local → GCE ────────────────

log "Step 2: Transferring database dumps..."

log "Downloading dumps from Lightsail..."
scp "$LIGHTSAIL:/tmp/kanbn-migrate-$DATE.sql.gz" "$LOCAL_DUMP_DIR/"
scp "$LIGHTSAIL:/tmp/outline-migrate-$DATE.sql.gz" "$LOCAL_DUMP_DIR/"

log "Uploading dumps to GCE..."
scp "$LOCAL_DUMP_DIR/kanbn-migrate-$DATE.sql.gz" "$GCE:/tmp/"
scp "$LOCAL_DUMP_DIR/outline-migrate-$DATE.sql.gz" "$GCE:/tmp/"

# ── Step 3: Deploy all services to GCE ─────────────────────────────

log "Step 3: Deploying all services to GCE..."
"$REPO_ROOT/scripts/deploy-to.sh" "$GCE_IP" all

# ── Step 4: Restore databases on GCE ──────────────────────────────

log "Step 4: Restoring databases on GCE..."

log "Waiting for PostgreSQL containers to be ready..."
sleep 15

log "Restoring Kan.bn database..."
ssh "$GCE" "docker exec -i kanbn_postgres bash -c \"psql -U kanbn -c \\\"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'kanbn' AND pid <> pg_backend_pid();\\\" postgres && dropdb -U kanbn --if-exists kanbn && createdb -U kanbn kanbn\""
ssh "$GCE" "gunzip -c /tmp/kanbn-migrate-$DATE.sql.gz | docker exec -i kanbn_postgres psql -U kanbn kanbn"

log "Restoring Outline database..."
ssh "$GCE" "docker exec -i outline_postgres bash -c \"psql -U outline -c \\\"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'outline' AND pid <> pg_backend_pid();\\\" postgres && dropdb -U outline --if-exists outline && createdb -U outline outline\""
ssh "$GCE" "gunzip -c /tmp/outline-migrate-$DATE.sql.gz | docker exec -i outline_postgres psql -U outline outline"

log "Restarting services after restore..."
ssh "$GCE" "cd ~/apps/kanbn && docker compose restart"
ssh "$GCE" "cd ~/apps/outline && docker compose restart"

# ── Step 5: Sync MinIO data ────────────────────────────────────────

log "Step 5: Syncing MinIO data..."

# Install mc (MinIO client) on Lightsail if not present
ssh "$LIGHTSAIL" "command -v mc > /dev/null 2>&1 || { curl -sSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc && chmod +x /usr/local/bin/mc; }" || {
    warn "Could not install mc on Lightsail — install manually and re-run"
}

# Extract MinIO credentials from Outline secrets
MINIO_ROOT_USER=$(sops -d "$REPO_ROOT/outline/secrets.yaml" | yq -r '.minio_root_user')
MINIO_ROOT_PASSWORD=$(sops -d "$REPO_ROOT/outline/secrets.yaml" | yq -r '.minio_root_password')

log "Configuring mc on Lightsail (source)..."
ssh "$LIGHTSAIL" "mc alias set src http://localhost:9000 '$MINIO_ROOT_USER' '$MINIO_ROOT_PASSWORD' --api s3v4"

log "Configuring mc on Lightsail pointing to GCE MinIO (destination)..."
ssh "$LIGHTSAIL" "mc alias set dst http://$GCE_IP:9000 '$MINIO_ROOT_USER' '$MINIO_ROOT_PASSWORD' --api s3v4"

log "Mirroring MinIO buckets..."
for bucket in outline-data kanbn-avatars kanbn-attachments; do
    if ssh "$LIGHTSAIL" "mc ls src/$bucket > /dev/null 2>&1"; then
        log "  Mirroring $bucket..."
        ssh "$LIGHTSAIL" "mc mirror --overwrite src/$bucket dst/$bucket"
    else
        warn "  Bucket $bucket not found on source, skipping"
    fi
done

# ── Step 6: Verification ──────────────────────────────────────────

log "Step 6: Running verification checks..."

echo ""
log "Checking service health on GCE..."

check_service() {
    local name=$1
    local port=$2
    if ssh "$GCE" "curl -sf -o /dev/null http://localhost:$port" 2>/dev/null; then
        log "  $name (port $port): OK"
    else
        warn "  $name (port $port): NOT RESPONDING (may still be starting)"
    fi
}

check_service "Kan.bn" 3003
check_service "Outline" 3002
check_service "MinIO" 9000

echo ""
log "Checking Docker containers on GCE..."
ssh "$GCE" "docker ps --format 'table {{.Names}}\t{{.Status}}'"

# ── Cleanup ────────────────────────────────────────────────────────

log "Cleaning up temporary files..."
ssh "$LIGHTSAIL" "rm -f /tmp/kanbn-migrate-$DATE.sql.gz /tmp/outline-migrate-$DATE.sql.gz"
ssh "$GCE" "rm -f /tmp/kanbn-migrate-$DATE.sql.gz /tmp/outline-migrate-$DATE.sql.gz"
rm -f "$LOCAL_DUMP_DIR/kanbn-migrate-$DATE.sql.gz" "$LOCAL_DUMP_DIR/outline-migrate-$DATE.sql.gz"

echo ""
log "========================================="
log "  Migration complete!"
log "========================================="
log ""
log "Next steps:"
log "  1. Verify services at https://tasks.xdeca.com and https://kb.xdeca.com"
log "  2. Update DNS to point to $GCE_IP"
log "  3. Test backups: ssh $GCE '/opt/scripts/backup.sh all'"
log "  4. Decommission Lightsail once confirmed"
