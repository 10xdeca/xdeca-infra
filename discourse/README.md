# Discourse Setup

Discourse uses its own container management system, not standard docker-compose.

## Installation on VPS

```bash
cd ~/apps
git clone https://github.com/discourse/discourse_docker.git discourse
cd discourse
```

## Configuration

Copy and edit the app config:

```bash
cp samples/standalone.yml containers/app.yml
nano containers/app.yml
```

Edit these values in `app.yml`:

```yaml
env:
  DISCOURSE_HOSTNAME: discourse.yourdomain.com
  DISCOURSE_DEVELOPER_EMAILS: 'your@email.com'
  DISCOURSE_SMTP_ADDRESS: smtp.mailgun.org
  DISCOURSE_SMTP_PORT: 587
  DISCOURSE_SMTP_USER_NAME: postmaster@mg.yourdomain.com
  DISCOURSE_SMTP_PASSWORD: your-smtp-password
```

## Bootstrap & Start

```bash
./launcher bootstrap app   # First time only (takes 5-10 min)
./launcher start app
```

## Common Commands

```bash
./launcher logs app        # View logs
./launcher restart app     # Restart
./launcher rebuild app     # Rebuild after config changes
./launcher enter app       # Shell into container
```

## Port

Discourse runs on port 8888 (configured in app.yml expose section).

## SMTP Requirement

Discourse requires working SMTP for email verification. Options:
- Mailgun (free tier: 1000 emails/month)
- Brevo (free tier: 300 emails/day)
- Amazon SES
