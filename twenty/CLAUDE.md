# Twenty CRM - xdeca

## Overview
Twenty is an open-source CRM (Salesforce alternative). Part of the xdeca VPS deployment.

See ~/git/orgs/xdeca/oci-vps/CLAUDE.md for full VPS architecture.

## Deployment

Twenty runs on port 3000, proxied by Caddy at `twenty.yourdomain.com`.

### Files
- `docker-compose.yml` - Podman/Docker compose configuration
- `.env.example` - Template for environment variables
- `.env` - Actual secrets (NOT in git)

### Services
- **server** - Main Twenty application (port 3000)
- **worker** - Background job processor
- **db** - PostgreSQL 16 database
- **redis** - Cache and job queue

## Setup on VPS

```bash
cd ~/apps/twenty

# Create .env from template
cp .env.example .env

# Generate secrets
POSTGRES_PASSWORD=$(openssl rand -hex 16)
APP_SECRET=$(openssl rand -hex 32)

# Edit .env with your values
nano .env

# Start services
podman-compose up -d

# Check logs
podman-compose logs -f server
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| SERVER_URL | Public URL with https | https://twenty.xdeca.com |
| POSTGRES_PASSWORD | Database password | (generated) |
| APP_SECRET | Application secret | (generated) |
| TAG | Image version | latest |

## Backup

```bash
# Dump database
podman exec twenty_db_1 pg_dump -U twenty twenty > twenty_backup.sql

# Restore
cat twenty_backup.sql | podman exec -i twenty_db_1 psql -U twenty twenty
```

## Troubleshooting

### Check service health
```bash
podman-compose ps
podman-compose logs server
```

### Restart services
```bash
podman-compose restart
```

### Full rebuild
```bash
podman-compose down
podman-compose pull
podman-compose up -d
```

## Alternative: Native Podman Setup (No Compose)

Based on [Dan Craig's Medium article](https://medium.com/@danielxcraig/self-host-twenty-crm-using-podman-ff60669350b0), you can run Twenty using native Podman pods instead of podman-compose. This approach uses `pg-boss` for the message queue instead of Redis.

### Create Volumes

```bash
podman volume create db-data
podman volume create docker-data
podman volume create server-local-data
```

### Create Pod

```bash
podman pod create --name twenty -p 3000:3000
```

### Create Database Container

```bash
podman create \
  --name twentydb \
  --pod twenty \
  -v db-data:/bitnami/postgresql \
  -e POSTGRES_PASSWORD={strong-password} \
  docker.io/twentycrm/twenty-postgres:main
```

### Generate Token Secrets

Run this 4 times and save each output:

```bash
openssl rand -base64 32
```

### Create Server Container

```bash
podman create \
  --name twentyserver \
  --pod twenty \
  -v server-local-data:/app/packages/twenty-server/.local-storage \
  -v docker-data:/app/docker-data \
  -e PORT=3000 \
  -e PG_DATABASE_URL=postgres://twenty:twenty@twentydb:5432/default \
  -e SERVER_URL=https://twenty.yourdomain.com \
  -e FRONT_BASE_URL=https://twenty.yourdomain.com \
  -e MESSAGE_QUEUE_TYPE=pg-boss \
  -e ENABLE_DB_MIGRATIONS=true \
  -e SIGN_IN_PREFILLED=true \
  -e STORAGE_TYPE=local \
  -e ACCESS_TOKEN_SECRET={token-1} \
  -e LOGIN_TOKEN_SECRET={token-2} \
  -e REFRESH_TOKEN_SECRET={token-3} \
  -e FILE_TOKEN_SECRET={token-4} \
  docker.io/twentycrm/twenty:main
```

### Create Worker Container

```bash
podman create \
  --name twentyworker \
  --pod twenty \
  -e PG_DATABASE_URL=postgres://twenty:twenty@twentydb:5432/default \
  -e SERVER_URL=https://twenty.yourdomain.com \
  -e FRONT_BASE_URL=https://twenty.yourdomain.com \
  -e MESSAGE_QUEUE_TYPE=pg-boss \
  -e ENABLE_DB_MIGRATIONS=false \
  -e STORAGE_TYPE=local \
  -e ACCESS_TOKEN_SECRET={token-1} \
  -e LOGIN_TOKEN_SECRET={token-2} \
  -e REFRESH_TOKEN_SECRET={token-3} \
  -e FILE_TOKEN_SECRET={token-4} \
  docker.io/twentycrm/twenty:main
```

### Start the Pod

```bash
podman pod start twenty
```

### Key Differences from Compose Setup

| Aspect | Compose Setup | Native Podman |
|--------|---------------|---------------|
| Message Queue | Redis | pg-boss (PostgreSQL) |
| DB Image | PostgreSQL 16 | twentycrm/twenty-postgres |
| Secrets | APP_SECRET | 4 separate token secrets |
| Management | podman-compose commands | podman pod commands |

## Future Plans

### MCP Server Integration

Add [Twenty CRM MCP Server](https://github.com/mhenry3164/twenty-crm-mcp-server) to enable AI-assisted CRM management via Claude.

**Features:**
- CRUD operations for people, companies, tasks, and notes
- Dynamic schema discovery (adapts to custom fields)
- Advanced cross-object search
- Natural language interface for CRM data
- Real-time syncing

**Setup (for Claude Desktop):**

1. Get API key from Twenty: Settings → API & Webhooks
2. Add to Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "twenty-crm": {
      "command": "npx",
      "args": ["-y", "twenty-crm-mcp-server"],
      "env": {
        "TWENTY_API_KEY": "your-api-key",
        "TWENTY_BASE_URL": "https://twenty.yourdomain.com"
      }
    }
  }
}
```

3. Restart Claude Desktop

## Resources
- [Twenty Documentation](https://docs.twenty.com)
- [Twenty GitHub](https://github.com/twentyhq/twenty)
- [Self-hosting Guide](https://twenty.com/developers/section/self-hosting/docker-compose)
- [Podman Setup Guide (Medium)](https://medium.com/@danielxcraig/self-host-twenty-crm-using-podman-ff60669350b0)
- [Twenty CRM MCP Server](https://github.com/mhenry3164/twenty-crm-mcp-server)
