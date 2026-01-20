#cloud-config

package_update: true
package_upgrade: true

packages:
  - podman
  - podman-compose
  - git
  - curl
  - htop
  - netcat-openbsd

# Create apps directory
runcmd:
  # Enable lingering for ubuntu user (keeps containers running)
  - loginctl enable-linger ubuntu

  # Set up apps directory
  - mkdir -p /home/ubuntu/apps
  - chown ubuntu:ubuntu /home/ubuntu/apps

  # Clone the infrastructure repo
  - su - ubuntu -c "git clone https://github.com/xdeca/oci-vps.git /home/ubuntu/apps"

  # Set up keep-alive to prevent idle reclamation
  - |
    cat > /opt/keep-alive.sh << 'KEEPALIVE'
    #!/bin/bash
    # Generate CPU activity to prevent Oracle from reclaiming idle instance
    dd if=/dev/urandom bs=1M count=100 | md5sum > /dev/null 2>&1
    echo "$(date): keep-alive ping" >> /var/log/keep-alive.log
    KEEPALIVE
  - chmod +x /opt/keep-alive.sh
  - echo "0 */6 * * * root /opt/keep-alive.sh" > /etc/cron.d/keep-alive

  # Open firewall ports
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable

  # Log completion
  - echo "Cloud-init setup complete at $(date)" >> /var/log/cloud-init-complete.log

write_files:
  # Readme for the server
  - path: /home/ubuntu/README.md
    owner: ubuntu:ubuntu
    permissions: '0644'
    content: |
      # xdeca VPS

      ## Services
      - OpenProject: https://openproject.${domain}
      - Twenty CRM: https://twenty.${domain}
      - Discourse: https://discourse.${domain}

      ## Directory Structure
      ~/apps/
        caddy/       - Reverse proxy
        openproject/ - Project management
        twenty/      - CRM
        discourse/   - Forum

      ## Start Services
      cd ~/apps/<service>
      podman-compose up -d

      ## Logs
      podman-compose logs -f

      ## Keep-alive
      Cron job runs every 6 hours to prevent Oracle reclaiming the instance.
      Check: cat /var/log/keep-alive.log
