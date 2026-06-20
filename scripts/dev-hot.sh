#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$REPO_ROOT/.tmp"
GENERATED_CADDYFILE="$TMP_DIR/dev-hot.Caddyfile"

# Dev runner: server + client hot reload + Caddy HTTP proxy.
# - Server: Gleam app in apps/server
# - Client: Lustre dev server in apps/client
# - Caddy: HTTP entrypoint proxying /api/v1/* -> server, everything else -> client

DATABASE_URL="${DATABASE_URL:-postgres://scrumbringer:scrumbringer@localhost:5432/scrumbringer_dev?sslmode=disable}"
SB_HOST="${SB_HOST:-0.0.0.0}"
SB_PORT="${SB_PORT:-8000}"
SB_UPSTREAM_HOST="${SB_UPSTREAM_HOST:-127.0.0.1}"
DEV_HOST="${DEV_HOST:-0.0.0.0}"
DEV_PORT="${DEV_PORT:-1234}"
DEV_UPSTREAM_HOST="${DEV_UPSTREAM_HOST:-127.0.0.1}"
SB_SECRET_KEY_BASE="${SB_SECRET_KEY_BASE:-dev-secret}"
SB_COOKIE_SECURE="${SB_COOKIE_SECURE:-false}"

CADDY_HTTP_HOST="${CADDY_HTTP_HOST:-0.0.0.0}"
CADDY_HTTP_PORT="${CADDY_HTTP_PORT:-8443}"

export DATABASE_URL
export SB_HOST SB_PORT SB_UPSTREAM_HOST SB_SECRET_KEY_BASE SB_COOKIE_SECURE
export DEV_HOST DEV_PORT DEV_UPSTREAM_HOST
export CADDY_HTTP_HOST CADDY_HTTP_PORT

PIDS=()

log() {
  printf '[dev-hot] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_free_port() {
  local host="$1"
  local port="$2"
  local label="$3"

  if ss -lnt | grep -Eq "[[:space:]]${host//./\.}:${port}[[:space:]]|[[:space:]]0\.0\.0\.0:${port}[[:space:]]|[[:space:]]\*:${port}[[:space:]]"; then
    printf 'Port already in use for %s: %s:%s\n' "$label" "$host" "$port" >&2
    exit 1
  fi
}

require_migrated_database() {
  log "Checking database schema"
  if ! bash "$REPO_ROOT/scripts/ht12-db-schema-check.sh"; then
    cat >&2 <<EOF

Database schema check failed for:
  ${DATABASE_URL}

The dev stack would start, but task claim and Pool flows can fail later as
generic database errors when HT-12 migrations are missing. Apply migrations:

  dbmate --url "${DATABASE_URL}" migrate

Then run scripts/dev-hot.sh again.
EOF
    exit 1
  fi
}

local_app_url() {
  printf 'http://127.0.0.1:%s' "$CADDY_HTTP_PORT"
}

lan_app_urls() {
  local ip
  local ips

  if ! command -v hostname >/dev/null 2>&1; then
    return 0
  fi

  ips="$(hostname -I 2>/dev/null || true)"
  for ip in $ips; do
    case "$ip" in
      127.* | *:*) ;;
      *.*.*.*) printf 'http://%s:%s\n' "$ip" "$CADDY_HTTP_PORT" ;;
    esac
  done
}

cleanup() {
  local pid

  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done

  wait 2>/dev/null || true
}

write_caddyfile() {
  mkdir -p "$TMP_DIR"

  cat >"$GENERATED_CADDYFILE" <<EOF
{
  admin off
}

http://:${CADDY_HTTP_PORT} {
  bind ${CADDY_HTTP_HOST}
  encode zstd gzip

  @api path /api/v1/*
  handle @api {
    reverse_proxy ${SB_UPSTREAM_HOST}:${SB_PORT}
  }

  handle {
    reverse_proxy ${DEV_UPSTREAM_HOST}:${DEV_PORT}
  }
}
EOF
}

start_background() {
  local name="$1"
  local workdir="$2"
  shift 2

  log "Starting $name"
  (
    cd "$workdir"
    exec "$@"
  ) &
  PIDS+=("$!")
}

main() {
  trap cleanup EXIT INT TERM

  require_cmd gleam
  require_cmd caddy
  require_cmd ss

  require_migrated_database

  require_free_port "$SB_HOST" "$SB_PORT" "server"
  require_free_port "$DEV_HOST" "$DEV_PORT" "client dev server"
  require_free_port "$CADDY_HTTP_HOST" "$CADDY_HTTP_PORT" "caddy http"

  write_caddyfile
  caddy validate --config "$GENERATED_CADDYFILE" --adapter caddyfile >/dev/null

  start_background \
    "server on ${SB_HOST}:${SB_PORT}" \
    "$REPO_ROOT/apps/server" \
    gleam run -m main

  start_background \
    "Lustre dev server on ${DEV_HOST}:${DEV_PORT}" \
    "$REPO_ROOT/apps/client" \
    gleam run -m lustre/dev start

  start_background \
    "Caddy on ${CADDY_HTTP_HOST}:${CADDY_HTTP_PORT}" \
    "$REPO_ROOT" \
    caddy run --config "$GENERATED_CADDYFILE" --adapter caddyfile

  printf '\n'
  log "Dev stack running"
  log "App local: $(local_app_url)"
  lan_app_urls | while read -r url; do
    log "App LAN: ${url}"
  done
  log "API origin: http://${SB_HOST}:${SB_PORT}/api/v1"
  log "Client dev origin: http://${DEV_HOST}:${DEV_PORT}"
  log "Database URL: ${DATABASE_URL}"
  printf '\n'
  log 'Press Ctrl+C to stop.'

  wait
}

main "$@"
