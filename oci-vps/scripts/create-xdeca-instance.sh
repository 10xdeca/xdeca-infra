#!/bin/bash
# Create Oracle Cloud free tier ARM instance with keep-alive
# Retries on "Out of capacity" errors

set -e

COMPARTMENT_ID="ocid1.tenancy.oc1..aaaaaaaa53sr57ghje45q5lkvqunbxbh45imq4rfblzsqvf7vk7y4sjait2a"
SUBNET_ID="ocid1.subnet.oc1.ap-melbourne-1.aaaaaaaa3sxklspcjmiddzuvkq7mlunze2sfm6r6qd3wcb4wmyyrqqmoe24q"
IMAGE_ID="ocid1.image.oc1.ap-melbourne-1.aaaaaaaaa23ah7oxjhhgcwyd56t6ydtghl2ovzqytnokzrv4233wyqpp5rka"
AVAILABILITY_DOMAIN="MNVQ:AP-MELBOURNE-1-AD-1"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519.pub"

# Create cloud-init file
CLOUD_INIT_FILE=$(mktemp)
cat > "$CLOUD_INIT_FILE" << 'EOF'
#!/bin/bash
# Keep-alive script to prevent Oracle from reclaiming idle instance

# Install keep-alive cron job
cat > /opt/keep-alive.sh << 'KEEPALIVE'
#!/bin/bash
# Generate some CPU activity every 6 hours
dd if=/dev/urandom bs=1M count=100 | md5sum > /dev/null 2>&1
# Log activity
echo "$(date): keep-alive ping" >> /var/log/keep-alive.log
KEEPALIVE

chmod +x /opt/keep-alive.sh

# Run every 6 hours
echo "0 */6 * * * root /opt/keep-alive.sh" > /etc/cron.d/keep-alive

# Also enable some basic monitoring to show activity
apt-get update
apt-get install -y htop curl netcat-openbsd

echo "Keep-alive setup complete" >> /var/log/cloud-init-output.log
EOF

echo "Creating xdeca instance..."
echo "This may fail with 'Out of capacity' - that's normal, just retry."
echo ""

SUPPRESS_LABEL_WARNING=True oci compute instance launch \
  --compartment-id "$COMPARTMENT_ID" \
  --availability-domain "$AVAILABILITY_DOMAIN" \
  --shape "VM.Standard.A1.Flex" \
  --shape-config '{"ocpus": 4, "memoryInGBs": 24}' \
  --subnet-id "$SUBNET_ID" \
  --image-id "$IMAGE_ID" \
  --display-name "xdeca" \
  --assign-public-ip true \
  --ssh-authorized-keys-file "$SSH_KEY_PATH" \
  --user-data-file "$CLOUD_INIT_FILE" \
  --boot-volume-size-in-gbs 50

RESULT=$?

# Clean up temp file
rm -f "$CLOUD_INIT_FILE"

if [ $RESULT -eq 0 ]; then
  echo ""
  echo "SUCCESS! Instance created with keep-alive configured."
  echo ""
  echo "Get public IP:"
  echo "  OCI Console → Compute → Instances → xdeca"
  echo ""
  echo "Or via CLI:"
  echo "  oci compute instance list-vnics --instance-id <ID> | jq -r '.data[0][\"public-ip\"]'"
else
  echo ""
  echo "Failed - likely 'Out of capacity'. Try again later."
  exit 1
fi
