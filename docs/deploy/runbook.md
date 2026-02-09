# Production Deploy Runbook

## Scope

Runbook for deploying Scrumbringer to a Linux host using:

- Gleam server (`apps/server`)
- Lustre client static assets (`apps/client/dist`)
- Nginx reverse proxy + TLS
- systemd services

## Prerequisites

1. Linux host with these packages installed:
   - `gleam`
   - `erlang`
   - `postgresql-client`
   - `dbmate`
   - `nginx`
2. Application code deployed to `/opt/scrumbringer`.
3. Dedicated OS users:
   - `scrumbringer`
4. PostgreSQL production database available.

## Environment Files

Copy and edit these files:

- `/etc/scrumbringer/server.env` from `deploy/server.env.example`

Critical variables:

- `DATABASE_URL`
- `SB_SECRET_KEY_BASE`

## Nginx Site Config

1. Copy site template:

```bash
sudo cp deploy/nginx/scrumbringer.conf.example /etc/nginx/conf.d/scrumbringer.conf
```

2. Replace placeholders in `/etc/nginx/conf.d/scrumbringer.conf`:

- `__APP_DOMAIN__`
- `__SSL_CERT__`
- `__SSL_KEY__`

3. Validate config:

```bash
sudo nginx -t
```

## Build + Test Gate

From repository root:

```bash
make release-check
```

Optional smoke checks:

```bash
RUN_SMOKE=1 make release-check
```

## Staging Smoke Gate

Run smoke tests against staging before production deploy:

```bash
make smoke-staging \
  STAGING_BASE_URL="https://staging.example.com" \
  STAGING_API_URL="https://staging.example.com" \
  SMOKE_EMAIL="admin@example.com" \
  SMOKE_PASSWORD="..." \
  SMOKE_TASK_ID="1"
```

Or run full pre-go-live gate in one command:

```bash
make pre-go-live \
  STAGING_BASE_URL="https://staging.example.com" \
  STAGING_API_URL="https://staging.example.com" \
  SMOKE_EMAIL="admin@example.com" \
  SMOKE_PASSWORD="..." \
  SMOKE_TASK_ID="1"
```

## Build Artifacts

```bash
scripts/build-prod.sh
```

This compiles all Gleam apps/packages and generates client dist via:

- `gleam run -m lustre/dev build`

## Database Migration

Run before restarting services:

```bash
DATABASE_URL="postgres://..." make migrate
```

## Install/Enable systemd Units

```bash
sudo cp deploy/systemd/scrumbringer-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable scrumbringer-server
sudo systemctl enable nginx
```

## Deploy Procedure

1. Pull latest code into `/opt/scrumbringer`.
2. Run `make release-check`.
3. Run `scripts/build-prod.sh`.
4. Run migrations (`make migrate` with prod `DATABASE_URL`).
5. Restart server:

   ```bash
   sudo systemctl restart scrumbringer-server
   ```

6. Restart nginx:

   ```bash
   sudo systemctl restart nginx
   ```

7. Verify service health:

   ```bash
   curl -fsS https://<APP_DOMAIN>/api/v1/health
   ```

## Post-Deploy Smoke

1. Login in browser.
2. Validate key flows:
   - Create card
   - Create task
   - Milestone move flow
3. Check logs:

```bash
sudo journalctl -u scrumbringer-server -n 200 --no-pager
sudo journalctl -u nginx -n 200 --no-pager
```

## Rollback

1. Checkout previous known-good git tag/revision in `/opt/scrumbringer`.
2. Rebuild (`scripts/build-prod.sh`).
3. Restart services.
4. If a migration caused incompatibility, restore DB backup.

## Notes

- Keep `SB_COOKIE_SECURE=true` in production.
- Never commit production secrets to git.
- Prefer deploying through staging first.
- If you keep Caddy for dev/staging, do not run it in production with Nginx unless you have a deliberate double-proxy design.
