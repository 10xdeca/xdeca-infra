# CLAUDE.md - OpenProject

## Project Goal

Deploy **OpenProject** (project management) on Oracle Cloud Infrastructure.

## Deployment

### Podman compose

```yaml
version: "3.8"

services:
  openproject:
    image: openproject/openproject:17
    restart: always
    ports:
      - "8080:80"
    environment:
      - OPENPROJECT_HOST__NAME=openproject.yourdomain.com
      - OPENPROJECT_HTTPS=true
      - OPENPROJECT_DEFAULT__LANGUAGE=en
      - SECRET_KEY_BASE=${OPENPROJECT_SECRET}
    volumes:
      - pgdata:/var/openproject/pgdata
      - assets:/var/openproject/assets

volumes:
  pgdata:
  assets:
```

Generate secret: `openssl rand -hex 64`

**Default login:** admin / admin

## Resource Requirements

- **RAM**: ~2GB
- **CPU**: Low
- **Port**: 8080

## Backup

```bash
podman exec openproject_openproject_1 pg_dump -U postgres openproject > backup.sql
```

## VPS Setup

See `~/git/orgs/xdeca/oci-vps/CLAUDE.md` for OCI instance setup, Caddy reverse proxy, and DNS configuration.

## Future Plans: MCP Server Integration

Consider integrating an OpenProject MCP server to enable Claude to interact directly with OpenProject for task management, issue tracking, and project queries.

### MCP Server Options

- **[firsthalfhero/openproject-mcp-server](https://github.com/firsthalfhero/openproject-mcp-server)** - OpenProject MCP server implementation
- **[AndyEverything/openproject-mcp-server](https://github.com/AndyEverything/openproject-mcp-server)** - Alternative OpenProject MCP server

### Potential Benefits

- Create/update work packages directly from Claude
- Query project status and metrics
- Automate project management workflows
- Integrate with `/pm` skill for seamless task tracking

## Useful Links

- [OpenProject Docker docs](https://www.openproject.org/docs/installation-and-operations/installation/docker/)
