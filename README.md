# xdeca-infra

Infrastructure monorepo for self-hosted services.

## Services

| Service | Description | URL |
|---------|-------------|-----|
| [Kan.bn](./kanbn/) | Kanban boards (Trello alternative) | tasks.xdeca.com |
| [Outline](./outline/) | Team wiki (Notion alternative) | kb.xdeca.com |
| MinIO | S3-compatible file storage | storage.xdeca.com |
| [Caddy](./caddy/) | Reverse proxy with automatic HTTPS | - |

## Infrastructure

| Provider | Status | Cost |
|----------|--------|------|
| GCP Compute Engine (e2-medium) | **Active** | ~$24/mo |

## Architecture

```
Internet → Caddy (443/80) → Kan.bn (3003)
                          → Outline (3002)
                          → MinIO (9000)
```

## Quick Start

### Prerequisites

```bash
brew install sops age yq
```

### 1. Set up encryption key

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
# Add public key to .sops.yaml
```

### 2. Deploy services

```bash
./scripts/deploy-to.sh 34.116.110.7 all
```

## Repository Structure

```
.
├── caddy/                  # Reverse proxy config
├── kanbn/                  # Kan.bn (Trello alternative)
├── outline/                # Outline wiki
├── backups/                # Backup configuration
├── scripts/
│   ├── deploy-to.sh        # Deployment script
│   ├── backup.sh           # Backup script
│   └── restore.sh          # Restore script
└── .sops.yaml              # SOPS encryption config
```

## Secrets Management

All secrets are encrypted with [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).

```bash
# Edit encrypted secrets
sops kanbn/secrets.yaml
sops outline/secrets.yaml
```
