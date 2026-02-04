#!/usr/bin/env bash
set -euo pipefail

# Dev runner: server + client hot reload + Caddy TLS proxy
# - Server: Gleam (apps/server) on SB_PORT (default 8000)
# - Client: Lustre dev server (apps/client) on DEV_PORT (default 1234)
# - Caddy: https://localhost:8443 proxies /api/v1/* -> server, everything else -> client

DATABASE_URL=${DATABASE_URL:-"postgres://scrumbringer:scrumbringer@localhost:5432/scrumbringer_dev?sslmode=disable"}
SB_HOST=${SB_HOST:-0.0.0.0}
SB_PORT=${SB_PORT:-8000}
DEV_HOST=${DEV_HOST:-0.0.0.0}
DEV_PORT=${DEV_PORT:-1234}
SB_SECRET_KEY_BASE=${SB_SECRET_KEY_BASE:-dev-secret}
SB_COOKIE_SECURE=${SB_COOKIE_SECURE:-false}
CADDY_HTTP_HOST=${CADDY_HTTP_HOST:-0.0.0.0}
CADDY_HTTP_PORT=${CADDY_HTTP_PORT:-8080}
CADDY_HTTPS_HOST=${CADDY_HTTPS_HOST:-localhost}
CADDY_HTTPS_PORT=${CADDY_HTTPS_PORT:-8443}

export DATABASE_URL SB_HOST SB_PORT DEV_HOST DEV_PORT SB_SECRET_KEY_BASE SB_COOKIE_SECURE
export CADDY_HTTP_HOST CADDY_HTTP_PORT CADDY_HTTPS_HOST CADDY_HTTPS_PORT

cleanup() {
  # Best-effort cleanup.
  jobs -pr | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p .tmp

echo "Starting server on :$SB_PORT"
(
  cd apps/server
  DATABASE_URL="$DATABASE_URL" SB_HOST="$SB_HOST" SB_PORT="$SB_PORT" SB_SECRET_KEY_BASE="$SB_SECRET_KEY_BASE" \
    gleam run -m main
) &

echo "Starting Lustre dev server on :$DEV_PORT"
(
  cd apps/client
  DATABASE_URL="$DATABASE_URL" SB_PORT="$SB_PORT" SB_SECRET_KEY_BASE="$SB_SECRET_KEY_BASE" \
    DEV_HOST="$DEV_HOST" DEV_PORT="$DEV_PORT" \
    gleam run -m lustre/dev start
) &

# Prefer the local caddyfile that proxies to 1234.
CADDY_CONFIG=./caddyfile
if [ ! -f "$CADDY_CONFIG" ]; then
  echo "Missing ./caddyfile. Expected it to proxy to dev server." >&2
  exit 1
fi

echo "Starting Caddy (https://$CADDY_HTTPS_HOST:$CADDY_HTTPS_PORT)"
SB_PORT="$SB_PORT" DEV_PORT="$DEV_PORT" \
  CADDY_HTTP_HOST="$CADDY_HTTP_HOST" CADDY_HTTP_PORT="$CADDY_HTTP_PORT" \
  CADDY_HTTPS_HOST="$CADDY_HTTPS_HOST" CADDY_HTTPS_PORT="$CADDY_HTTPS_PORT" \
  caddy run --config "$CADDY_CONFIG" --adapter caddyfile &

echo
echo "Dev stack running:"
echo "- App (HTTPS): https://$CADDY_HTTPS_HOST:$CADDY_HTTPS_PORT"
echo "- App (HTTP):  http://$CADDY_HTTP_HOST:$CADDY_HTTP_PORT  (or http://<your-ip>:$CADDY_HTTP_PORT)"
echo "- API: http://localhost:$SB_PORT/api/v1"
echo "- Client dev: http://localhost:$DEV_PORT"
echo

echo "Press Ctrl+C to stop."
wait
