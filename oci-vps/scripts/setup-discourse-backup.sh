#!/bin/bash
# Setup Discourse backups to Oracle Cloud Object Storage
# Run this on the VPS after Discourse is installed

set -e

echo "=== Discourse Backup Setup for Oracle Object Storage ==="

# --- Configuration ---
BUCKET_NAME="discourse-backups"
NAMESPACE="nickmeinhold"  # Your OCI tenancy namespace
REGION="ap-melbourne-1"
BACKUP_SOURCE="/var/discourse/shared/standalone/backups/default"
RCLONE_REMOTE="oci-archive"

# --- Step 1: Install rclone ---
echo ""
echo "Step 1: Installing rclone..."
if ! command -v rclone &> /dev/null; then
    sudo apt update
    sudo apt install -y rclone
    echo "✓ rclone installed"
else
    echo "✓ rclone already installed"
fi

# --- Step 2: Create OCI bucket (if not exists) ---
echo ""
echo "Step 2: Creating Object Storage bucket..."
echo "Run this command (requires OCI CLI configured):"
echo ""
cat << 'EOF'
oci os bucket create \
  --compartment-id ocid1.tenancy.oc1..aaaaaaaa53sr57ghje45q5lkvqunbxbh45imq4rfblzsqvf7vk7y4sjait2a \
  --name discourse-backups \
  --storage-tier Archive \
  --public-access-type NoPublicAccess
EOF
echo ""

# --- Step 3: Create Customer Secret Key for S3 compatibility ---
echo "Step 3: Create S3-compatible credentials"
echo ""
echo "Go to OCI Console:"
echo "  1. Profile (top right) → User Settings"
echo "  2. Resources → Customer Secret Keys"
echo "  3. Generate Secret Key"
echo "  4. Save the Access Key and Secret Key (shown only once!)"
echo ""
read -p "Press Enter after you have the keys..."

# --- Step 4: Configure rclone ---
echo ""
echo "Step 4: Configuring rclone..."

read -p "Enter your Access Key: " ACCESS_KEY
read -sp "Enter your Secret Key: " SECRET_KEY
echo ""

mkdir -p ~/.config/rclone

cat > ~/.config/rclone/rclone.conf << EOF
[${RCLONE_REMOTE}]
type = s3
provider = Other
env_auth = false
access_key_id = ${ACCESS_KEY}
secret_access_key = ${SECRET_KEY}
endpoint = https://${NAMESPACE}.compat.objectstorage.${REGION}.oraclecloud.com
acl = private
EOF

chmod 600 ~/.config/rclone/rclone.conf
echo "✓ rclone configured"

# --- Step 5: Test connection ---
echo ""
echo "Step 5: Testing connection..."
if rclone lsd ${RCLONE_REMOTE}: 2>/dev/null; then
    echo "✓ Connection successful"
else
    echo "✗ Connection failed - check your credentials"
    exit 1
fi

# --- Step 6: Create backup script ---
echo ""
echo "Step 6: Creating backup sync script..."

sudo mkdir -p /opt/scripts
sudo tee /opt/scripts/sync-discourse-backups.sh > /dev/null << 'SCRIPT'
#!/bin/bash
# Sync Discourse backups to Oracle Cloud Object Storage

LOG="/var/log/discourse-backup-sync.log"
REMOTE="oci-archive"
BUCKET="discourse-backups"
SOURCE="/var/discourse/shared/standalone/backups/default"

echo "$(date): Starting backup sync..." >> $LOG

# Only sync .tar.gz backup files
if rclone sync "$SOURCE" "${REMOTE}:${BUCKET}" \
    --include "*.tar.gz" \
    --config /home/ubuntu/.config/rclone/rclone.conf \
    --log-file=$LOG \
    --log-level INFO; then
    echo "$(date): Backup sync completed successfully" >> $LOG
else
    echo "$(date): Backup sync FAILED" >> $LOG
    exit 1
fi
SCRIPT

sudo chmod +x /opt/scripts/sync-discourse-backups.sh
echo "✓ Backup script created at /opt/scripts/sync-discourse-backups.sh"

# --- Step 7: Setup cron job ---
echo ""
echo "Step 7: Setting up daily cron job..."

# Run at 4 AM daily (after Discourse's built-in backup at 3 AM)
(crontab -l 2>/dev/null | grep -v sync-discourse-backups; echo "0 4 * * * /opt/scripts/sync-discourse-backups.sh") | crontab -
echo "✓ Cron job added (runs daily at 4 AM)"

# --- Step 8: Configure Discourse built-in backups ---
echo ""
echo "Step 8: Configure Discourse backup settings"
echo ""
echo "In Discourse Admin → Settings → Backups:"
echo "  - backup_frequency: 1 (daily)"
echo "  - maximum_backups: 2 (keep only 2 locally)"
echo "  - backup_time_of_day: 3 (3 AM)"
echo "  - include_uploads_in_backups: true"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "To test manually:"
echo "  sudo /opt/scripts/sync-discourse-backups.sh"
echo ""
echo "To check sync logs:"
echo "  tail -f /var/log/discourse-backup-sync.log"
echo ""
echo "To list remote backups:"
echo "  rclone ls ${RCLONE_REMOTE}:${BUCKET_NAME}"
echo ""
echo "=== RESTORE INSTRUCTIONS ==="
echo ""
echo "See: /opt/scripts/restore-discourse-backup.sh"

# --- Create restore script ---
sudo tee /opt/scripts/restore-discourse-backup.sh > /dev/null << 'RESTORE'
#!/bin/bash
# Restore Discourse from Oracle Cloud Object Storage backup
#
# IMPORTANT: Archive-tier objects need to be restored before download.
# This process takes ~1 hour for Archive tier.

set -e

REMOTE="oci-archive"
BUCKET="discourse-backups"
RESTORE_DIR="/var/discourse/shared/standalone/backups/default"
CONFIG="/home/ubuntu/.config/rclone/rclone.conf"

echo "=== Discourse Restore from Oracle Object Storage ==="
echo ""

# List available backups
echo "Available backups:"
echo ""
rclone ls ${REMOTE}:${BUCKET} --config $CONFIG
echo ""

read -p "Enter backup filename to restore (e.g., discourse-2024-01-15.tar.gz): " BACKUP_FILE

if [ -z "$BACKUP_FILE" ]; then
    echo "No filename provided. Exiting."
    exit 1
fi

echo ""
echo "IMPORTANT: Archive-tier objects must be restored before download."
echo "This is a two-step process:"
echo ""
echo "Step 1: Request object restore (initiates retrieval from cold storage)"
echo "Step 2: Download once available (~1 hour for Archive tier)"
echo ""

read -p "Proceed with restore request? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Step 1: Requesting object restore from Archive tier..."
echo ""
echo "Run this OCI CLI command to initiate restore:"
echo ""
cat << EOF
oci os object restore \\
  --namespace nickmeinhold \\
  --bucket-name ${BUCKET} \\
  --name "${BACKUP_FILE}" \\
  --hours 24
EOF
echo ""
echo "This makes the object downloadable for 24 hours."
echo ""
read -p "Press Enter after running the above command..."

echo ""
echo "Step 2: Checking restore status..."
echo ""
echo "Run this to check status (wait for 'archival-state: Available'):"
echo ""
cat << EOF
oci os object head \\
  --namespace nickmeinhold \\
  --bucket-name ${BUCKET} \\
  --name "${BACKUP_FILE}" | grep archival-state
EOF
echo ""
echo "Status meanings:"
echo "  - Archived: Still in cold storage, not downloadable"
echo "  - Restoring: Retrieval in progress (~1 hour)"
echo "  - Available: Ready to download"
echo ""
read -p "Press Enter when status shows 'Available'..."

echo ""
echo "Step 3: Downloading backup..."
rclone copy ${REMOTE}:${BUCKET}/${BACKUP_FILE} ${RESTORE_DIR}/ --config $CONFIG --progress

if [ -f "${RESTORE_DIR}/${BACKUP_FILE}" ]; then
    echo ""
    echo "✓ Backup downloaded to: ${RESTORE_DIR}/${BACKUP_FILE}"
    echo ""
    echo "Step 4: Restore via Discourse"
    echo ""
    echo "Option A - Via Admin UI:"
    echo "  1. Go to Admin → Backups"
    echo "  2. The backup should appear in the list"
    echo "  3. Click 'Restore'"
    echo ""
    echo "Option B - Via command line:"
    echo "  cd /var/discourse"
    echo "  ./launcher enter app"
    echo "  discourse restore ${BACKUP_FILE}"
    echo ""
    echo "After restore, rebuild the container:"
    echo "  cd /var/discourse"
    echo "  ./launcher rebuild app"
else
    echo "✗ Download failed"
    exit 1
fi
RESTORE

sudo chmod +x /opt/scripts/restore-discourse-backup.sh
echo "✓ Restore script created at /opt/scripts/restore-discourse-backup.sh"
