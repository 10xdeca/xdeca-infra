# OCI VPS Multi-Account Provisioning

Auto-retry provisioning across multiple OCI accounts until an ARM instance is obtained.

## Setup New Account

### 1. Configure OCI CLI profile

```bash
# Add new profile to ~/.oci/config
oci setup config --profile sydney
```

This will prompt for:
- Tenancy OCID (from OCI Console → Profile → Tenancy)
- User OCID (from OCI Console → Profile → My profile)
- Region (e.g., `ap-sydney-1`)
- Generate new API key or use existing

### 2. Set up networking in OCI Console

For the new account:

1. **Create VCN** (if not exists):
   - Networking → Virtual Cloud Networks → Start VCN Wizard
   - Choose "Create VCN with Internet Connectivity"

2. **Get Subnet OCID**:
   - VCN → Subnets → Public Subnet → Copy OCID

3. **Get Ubuntu Image OCID**:
   - Compute → Images → Platform Images
   - Filter: Ubuntu, aarch64
   - Copy OCID for Ubuntu 22.04 or 24.04

4. **Get Availability Domain**:
   - Compute → Instances → Create Instance
   - Note the AD name (e.g., `AP-SYDNEY-1-AD-1`)
   - Cancel the wizard

5. **Open firewall ports**:
   - VCN → Security Lists → Default
   - Add Ingress: TCP 22, 80, 443, 8448

### 3. Update accounts.yaml

Edit `accounts.yaml` with the new account details:

```yaml
  - name: sydney
    profile: sydney
    region: ap-sydney-1
    compartment_id: "ocid1.tenancy.oc1..xxxxx"
    subnet_id: "ocid1.subnet.oc1.ap-sydney-1.xxxxx"
    image_id: "ocid1.image.oc1.ap-sydney-1.xxxxx"
    availability_domain: "xxxx:AP-SYDNEY-1-AD-1"
    instance_name: "xdeca-syd"
```

### 4. Test provisioning

```bash
# Test single run
./retry-provision.sh

# Check log
tail -f ~/oci-provision.log
```

## Pi Auto-Retry Setup

The Pi runs a cron job to retry provisioning every 5 minutes:

```bash
# On Pi
crontab -e
# Add:
*/5 * * * * ~/xdeca-infra/oci-vps/retry-provision.sh
```

## Notifications

Provisioning status is sent to ntfy.sh topic `xdeca-oci-alerts`.

Subscribe on phone:
- Install ntfy app
- Subscribe to topic: `xdeca-oci-alerts`

## Files

| File | Purpose |
|------|---------|
| `accounts.yaml` | OCI account configurations |
| `retry-provision.sh` | Multi-account retry script |
| `scripts/create-xdeca-instance.sh` | Single-account script (legacy) |

## Check Status

```bash
# View provisioning log
ssh pi "tail -50 ~/oci-provision.log"

# Check cron is running
ssh pi "crontab -l | grep oci"

# Manual trigger
ssh pi "~/xdeca-infra/oci-vps/retry-provision.sh"
```
