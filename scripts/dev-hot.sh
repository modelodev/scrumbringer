#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$REPO_ROOT/.tmp"
GENERATED_CADDYFILE="$TMP_DIR/dev-hot.Caddyfile"
STATE_FILE="$TMP_DIR/dev-hot.state"

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
HEALTH_MONITOR_INTERVAL="${HEALTH_MONITOR_INTERVAL:-10}"
HEALTH_MONITOR_FAILURES="${HEALTH_MONITOR_FAILURES:-3}"

export DATABASE_URL
export SB_HOST SB_PORT SB_UPSTREAM_HOST SB_SECRET_KEY_BASE SB_COOKIE_SECURE
export DEV_HOST DEV_PORT DEV_UPSTREAM_HOST
export CADDY_HTTP_HOST CADDY_HTTP_PORT
export HEALTH_MONITOR_INTERVAL HEALTH_MONITOR_FAILURES

PIDS=()
LAST_STARTED_PID=""
SERVER_PID=""
CLIENT_PID=""
CADDY_PID=""

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
  rm -f "$STATE_FILE"
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
  LAST_STARTED_PID="$!"
  PIDS+=("$LAST_STARTED_PID")
}

start_health_monitor() {
  local root_pid="$$"

  if [ "$HEALTH_MONITOR_INTERVAL" = "0" ]; then
    log "Health monitor disabled"
    return 0
  fi

  log "Starting health monitor every ${HEALTH_MONITOR_INTERVAL}s"
  (
    local failures=0

    while sleep "$HEALTH_MONITOR_INTERVAL"; do
      if APP_ORIGIN="$(local_app_url)" \
        HEALTH_RETRIES=1 \
        "$SCRIPT_DIR/dev-hot-health.sh" >/dev/null 2>&1; then
        failures=0
      else
        failures=$((failures + 1))
        log "Health monitor failure ${failures}/${HEALTH_MONITOR_FAILURES}"

        if [ "$failures" -ge "$HEALTH_MONITOR_FAILURES" ]; then
          log "Dev stack became unhealthy; stopping. Restart scripts/dev-hot.sh after client JS tests/builds."
          kill -TERM "$root_pid" 2>/dev/null || true
          exit 1
        fi
      fi
    done
  ) &

  PIDS+=("$!")
}

write_state() {
  mkdir -p "$TMP_DIR"

  {
    printf 'REPO_ROOT=%q\n' "$REPO_ROOT"
    printf 'APP_URL=%q\n' "$(local_app_url)"
    printf 'DATABASE_URL=%q\n' "$DATABASE_URL"
    printf 'SB_HOST=%q\n' "$SB_HOST"
    printf 'SB_PORT=%q\n' "$SB_PORT"
    printf 'DEV_HOST=%q\n' "$DEV_HOST"
    printf 'DEV_PORT=%q\n' "$DEV_PORT"
    printf 'CADDY_HTTP_HOST=%q\n' "$CADDY_HTTP_HOST"
    printf 'CADDY_HTTP_PORT=%q\n' "$CADDY_HTTP_PORT"
    printf 'SERVER_PID=%q\n' "$SERVER_PID"
    printf 'CLIENT_PID=%q\n' "$CLIENT_PID"
    printf 'CADDY_PID=%q\n' "$CADDY_PID"
  } >"$STATE_FILE"
}

main() {
  trap cleanup EXIT INT TERM

  require_cmd gleam
  require_cmd caddy
  require_cmd ss

  require_free_port "$SB_HOST" "$SB_PORT" "server"
  require_free_port "$DEV_HOST" "$DEV_PORT" "client dev server"
  require_free_port "$CADDY_HTTP_HOST" "$CADDY_HTTP_PORT" "caddy http"

  write_caddyfile
  caddy validate --config "$GENERATED_CADDYFILE" --adapter caddyfile >/dev/null

  start_background \
    "server on ${SB_HOST}:${SB_PORT}" \
    "$REPO_ROOT/apps/server" \
    gleam run -m main
  SERVER_PID="$LAST_STARTED_PID"

  start_background \
    "Lustre dev server on ${DEV_HOST}:${DEV_PORT}" \
    "$REPO_ROOT/apps/client" \
    gleam run -m lustre/dev start --host="$DEV_HOST" --port="$DEV_PORT"
  CLIENT_PID="$LAST_STARTED_PID"

  start_background \
    "Caddy on ${CADDY_HTTP_HOST}:${CADDY_HTTP_PORT}" \
    "$REPO_ROOT" \
    caddy run --config "$GENERATED_CADDYFILE" --adapter caddyfile
  CADDY_PID="$LAST_STARTED_PID"

  write_state

  log "Waiting for dev stack health"
  APP_ORIGIN="$(local_app_url)" \
    HEALTH_RETRIES="${HEALTH_RETRIES:-60}" \
    HEALTH_SLEEP="${HEALTH_SLEEP:-1}" \
    "$SCRIPT_DIR/dev-hot-health.sh"
  start_health_monitor

  printf '\n'
  log "Dev stack running"
  log "State: $STATE_FILE"
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
