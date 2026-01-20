# Discourse for xdeca

## Goal
Run Discourse on Oracle Cloud VPS (xdeca). Currently testing on Kamatera before migration.

## Current Status

**Kamatera (temporary/testing):** Running at `79.108.224.225`

## Migration Plan
1. Create test content on Kamatera instance
2. Back up Discourse (database + uploads)
3. Set up Discourse on Oracle Cloud VPS
4. Restore backup to Oracle instance
5. Verify migration successful
6. Update DNS and decommission Kamatera

## Email Provider: Brevo

Chosen for transactional emails. Setup steps:
1. Sign up at https://www.brevo.com
2. Get SMTP credentials from Settings -> SMTP & API
   - Server: `smtp-relay.brevo.com`
   - Port: `587`
   - Login: Your Brevo email
   - Password: Generate SMTP key
3. Verify sending domain in Settings -> Senders, Domains & Dedicated IPs -> Domains
4. Add SPF and DKIM DNS records provided by Brevo

## Server Access

```bash
ssh xdeca   # root@79.108.224.225
```

Discourse running on port **8888** (http://79.108.224.225:8888)

## Deployment Notes

### Docker/Podman
```bash
sudo apt update && sudo apt install -y podman podman-docker
```

### Discourse Install
Standard Discourse install:
```bash
sudo git clone https://github.com/discourse/discourse_docker.git /var/discourse
cd /var/discourse && sudo chmod 700 containers && sudo ./discourse-setup
```

Enter during setup:
- Hostname (e.g., forum.xdeca.com)
- Admin email
- SMTP settings from Brevo

### DNS Setup
Point A record for forum subdomain to `79.108.224.225`.

### Complete Setup
Register admin account via activation email.

## Key Information Still Needed
- Forum subdomain (e.g., `forum.xdeca.com`)
- Brevo SMTP credentials
- Admin email address(es)

## Technical Notes
- Discourse uses PostgreSQL and Redis (bundled in container)
- Uploads stored in filesystem by default, can use S3

## Future Work: Discourse Bot

Create a bot for automation tasks. Options:

### Option 1: Custom Plugin
- Develop a Discourse plugin (Ruby/Ember.js)
- Example projects to reference:
  - [Discourse Frotz](https://github.com/pschultz/discourse-frotz) - interactive fiction bot
  - [Discord Bot Construction Kit](https://github.com/discourse/discourse-chat-integration) - event-driven bot patterns
- API-only plugins tend to be more stable over time

### Option 2: Discourse Automation Plugin
- Built-in plugin, no separate installation needed
- UI-based configuration for scripts and triggers
- Simpler for common automation tasks

### Option 3: Discourse MCP (Model Context Protocol)
- Official CLI tool: `npm install -g @discourse/mcp@latest`
- Connects AI assistants (Claude, Gemini, ChatGPT, etc.) to Discourse via REST API
- Current capabilities: search topics, read posts, analyze threads, assist moderation
- Planned: writing/publishing posts, advanced moderation, analytics, webhooks
- No Discourse modification needed - standalone tool
- Blog post: https://blog.discourse.org/2025/10/discourse-mcp-is-here/

### Resources
- Discussion: https://meta.discourse.org/t/creating-bot-on-discourse/224822
- Discourse Plugin API docs: https://docs.discourse.org/

## Oracle Cloud VPS (Target)

The Oracle Cloud instance (xdeca) is pending due to capacity issues. See `../oci-vps/CLAUDE.md` for details.
A cron job on the Pi is retrying every 30 minutes.

### Deployment Steps (once xdeca is ready)

1. **Install Docker/Podman**
   ```bash
   ssh ubuntu@<ORACLE_VPS_IP>
   sudo apt update && sudo apt install -y podman podman-docker
   ```

2. **Install Discourse**
   ```bash
   sudo git clone https://github.com/discourse/discourse_docker.git /var/discourse
   cd /var/discourse && sudo chmod 700 containers && sudo ./discourse-setup
   ```

3. **Restore Backup**
   - Copy backup file from Kamatera
   - Restore via Admin > Backups

4. **Update DNS**
   - Point A record to Oracle VPS IP

### Notes
- ARM64 compatible (Oracle A1.Flex)
- Will run alongside Twenty and OpenProject

## Reference
- Official install guide: https://github.com/discourse/discourse/blob/main/docs/INSTALL-cloud.md
