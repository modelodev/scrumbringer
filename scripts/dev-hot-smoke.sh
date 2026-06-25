#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$REPO_ROOT/.tmp"
LOG_FILE="$TMP_DIR/dev-hot-smoke.log"

SB_PORT="${SB_PORT:-18000}"
DEV_PORT="${DEV_PORT:-11234}"
CADDY_HTTP_PORT="${CADDY_HTTP_PORT:-18443}"
DATABASE_URL="${DATABASE_URL:-postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable}"
APP_ORIGIN="http://127.0.0.1:$CADDY_HTTP_PORT"

DEV_PID=""

cleanup() {
  if [ -n "${DEV_PID:-}" ]; then
    kill -TERM "-$DEV_PID" 2>/dev/null || kill "$DEV_PID" 2>/dev/null || true
    wait "$DEV_PID" 2>/dev/null || true
    sleep 1
    kill -KILL "-$DEV_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

log() {
  printf '[dev-hot-smoke] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

wait_for_dev_hot_to_stop() {
  local attempts="${1:-20}"

  while [ "$attempts" -gt 0 ]; do
    if ! kill -0 "$DEV_PID" 2>/dev/null; then
      return 0
    fi

    sleep 1
    attempts=$((attempts - 1))
  done

  return 1
}

main() {
  require_cmd bash
  require_cmd curl
  require_cmd setsid

  mkdir -p "$TMP_DIR"
  rm -f "$LOG_FILE"

  log "Starting isolated dev-hot stack on ports server=$SB_PORT client=$DEV_PORT caddy=$CADDY_HTTP_PORT"
  (
    cd "$REPO_ROOT"
    exec env \
      DATABASE_URL="$DATABASE_URL" \
      SB_HOST=127.0.0.1 \
      SB_PORT="$SB_PORT" \
      DEV_HOST=127.0.0.1 \
      DEV_PORT="$DEV_PORT" \
      CADDY_HTTP_HOST=127.0.0.1 \
      CADDY_HTTP_PORT="$CADDY_HTTP_PORT" \
      HEALTH_RETRIES=60 \
      HEALTH_SLEEP=1 \
      HEALTH_MONITOR_INTERVAL="${HEALTH_MONITOR_INTERVAL:-2}" \
      HEALTH_MONITOR_FAILURES="${HEALTH_MONITOR_FAILURES:-2}" \
      setsid scripts/dev-hot.sh
  ) >"$LOG_FILE" 2>&1 &
  DEV_PID="$!"

  APP_ORIGIN="$APP_ORIGIN" HEALTH_RETRIES=90 \
    HEALTH_SLEEP=1 \
    "$SCRIPT_DIR/dev-hot-health.sh"

  log "Initial health passed"

  if [ "${RUN_JS_TEST_INVALIDATION_CHECK:-0}" = "1" ]; then
    log "Running client JS tests to check whether they invalidate a live dev server"
    (cd "$REPO_ROOT/apps/client" && gleam test --target javascript)

    if APP_ORIGIN="$APP_ORIGIN" HEALTH_RETRIES=1 "$SCRIPT_DIR/dev-hot-health.sh"; then
      log "Post-test health passed"
    else
      log "Post-test health failed; waiting for dev-hot monitor to stop the stale stack"

      if wait_for_dev_hot_to_stop 20; then
        log "Dev-hot monitor stopped the stale stack"
        DEV_PID=""
      else
        printf '[dev-hot-smoke] Dev-hot remained running while unhealthy\n' >&2
        return 1
      fi
    fi
  else
    log "Skipping JS test invalidation check; set RUN_JS_TEST_INVALIDATION_CHECK=1 to enable it"
  fi

  log "Smoke passed"
}

main "$@"
