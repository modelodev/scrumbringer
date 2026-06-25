#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="${DEV_HOT_STATE_FILE:-$REPO_ROOT/.tmp/dev-hot.state}"

APP_ORIGIN="${APP_ORIGIN:-}"

load_state() {
  if [ -f "$STATE_FILE" ]; then
    # shellcheck disable=SC1090
    . "$STATE_FILE"
  fi
}

pid_status() {
  local name="$1"
  local pid="${2:-}"

  if [ -z "$pid" ]; then
    printf '%s: unknown\n' "$name"
    return 0
  fi

  if kill -0 "$pid" 2>/dev/null; then
    printf '%s: running pid=%s\n' "$name" "$pid"
  else
    printf '%s: not running pid=%s\n' "$name" "$pid"
  fi
}

main() {
  load_state

  APP_ORIGIN="${APP_ORIGIN:-${APP_URL:-http://127.0.0.1:${CADDY_HTTP_PORT:-8443}}}"

  printf '[dev-hot-status] state: %s\n' "$STATE_FILE"
  printf '[dev-hot-status] app: %s\n' "$APP_ORIGIN"
  pid_status "server" "${SERVER_PID:-}"
  pid_status "client" "${CLIENT_PID:-}"
  pid_status "caddy" "${CADDY_PID:-}"

  printf '\n'
  if APP_ORIGIN="$APP_ORIGIN" "$SCRIPT_DIR/dev-hot-health.sh"; then
    printf '[dev-hot-status] healthy\n'
  else
    printf '[dev-hot-status] unhealthy\n' >&2
    printf '[dev-hot-status] If this happened after running client JS tests/builds, restart scripts/dev-hot.sh.\n' >&2
    return 1
  fi
}

main "$@"
