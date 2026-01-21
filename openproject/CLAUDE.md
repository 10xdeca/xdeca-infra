# OpenProject

**Default login:** admin / admin

## Backup

```bash
podman exec openproject_openproject_1 pg_dump -U postgres openproject > backup.sql
```

## MCP Server Integration (Future)

Potential OpenProject MCP servers for Claude integration:

- [firsthalfhero/openproject-mcp-server](https://github.com/firsthalfhero/openproject-mcp-server)
- [AndyEverything/openproject-mcp-server](https://github.com/AndyEverything/openproject-mcp-server)

Would enable creating/updating work packages, querying project status, and integrating with the `/pm` skill.
