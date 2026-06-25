#!/usr/bin/env bash
set -euo pipefail

APP_ORIGIN="${APP_ORIGIN:-http://127.0.0.1:${CADDY_HTTP_PORT:-8443}}"
HEALTH_RETRIES="${HEALTH_RETRIES:-1}"
HEALTH_SLEEP="${HEALTH_SLEEP:-1}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-5}"
CHECK_API="${CHECK_API:-1}"

TMP_DIR="${TMPDIR:-/tmp}"
BODY_FILE=""
FETCH_STATUS=""
FETCH_CONTENT_TYPE=""
FETCH_SIZE=""
FETCH_ERROR=""

cleanup() {
  if [ -n "${BODY_FILE:-}" ]; then
    rm -f "$BODY_FILE"
  fi
}

trap cleanup EXIT

fail() {
  printf '[dev-hot-health] %s\n' "$*" >&2
  exit 1
}

info() {
  printf '[dev-hot-health] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

new_body_file() {
  BODY_FILE="$TMP_DIR/dev-hot-health.$$"
  : >"$BODY_FILE"
}

fetch() {
  local path="$1"
  local result

  new_body_file
  FETCH_ERROR=""
  result="$(
    curl \
      --silent \
      --show-error \
      --location \
      --max-time "$HEALTH_TIMEOUT" \
      --output "$BODY_FILE" \
      --write-out '%{http_code}|%{content_type}|%{size_download}' \
      "${APP_ORIGIN}${path}" 2>&1
  )" || {
    FETCH_STATUS="000"
    FETCH_CONTENT_TYPE="curl_error"
    FETCH_SIZE="0"
    FETCH_ERROR="$result"
    return 0
  }

  IFS='|' read -r FETCH_STATUS FETCH_CONTENT_TYPE FETCH_SIZE <<<"$result"
}

content_type_is_html() {
  case "$1" in
    text/html*) return 0 ;;
    *) return 1 ;;
  esac
}

content_type_is_javascript() {
  case "$1" in
    application/javascript* | text/javascript* | application/ecmascript* | text/ecmascript*) return 0 ;;
    *) return 1 ;;
  esac
}

check_html() {
  local marker

  fetch "/"

  [ "$FETCH_STATUS" = "200" ] || fail "HTML health failed: GET / returned $FETCH_STATUS from $APP_ORIGIN"
  content_type_is_html "$FETCH_CONTENT_TYPE" || fail "HTML health failed: GET / content-type was '$FETCH_CONTENT_TYPE'"

  marker="/scrumbringer_client/scrumbringer_client.mjs"
  grep -Fq "$marker" "$BODY_FILE" || fail "HTML health failed: missing main module import '$marker'"
  grep -Fq "/.lustre/server-hot-reload.js" "$BODY_FILE" || fail "HTML health failed: missing Lustre hot reload script"

  info "HTML ok ($FETCH_SIZE bytes)"
}

check_js_asset() {
  local path="$1"
  local label="$2"
  local expected="$3"

  fetch "$path"

  [ "$FETCH_STATUS" = "200" ] || {
    case "$FETCH_STATUS" in
      502)
        fail "$label health failed: GET $path returned 502. The Lustre dev server is probably stale; restart scripts/dev-hot.sh after JS tests/builds."
        ;;
      404)
        fail "$label health failed: GET $path returned 404. The Lustre dev server is not serving expected dev assets."
        ;;
      000)
        fail "$label health failed: GET $path failed (${FETCH_ERROR:-curl error})"
        ;;
      *)
        fail "$label health failed: GET $path returned $FETCH_STATUS"
        ;;
    esac
  }

  content_type_is_javascript "$FETCH_CONTENT_TYPE" || fail "$label health failed: content-type was '$FETCH_CONTENT_TYPE'"
  [ "$FETCH_SIZE" -gt 0 ] || fail "$label health failed: empty response body"
  grep -Fq "$expected" "$BODY_FILE" || fail "$label health failed: response did not contain expected marker '$expected'"

  info "$label ok ($FETCH_SIZE bytes)"
}

check_api_proxy() {
  fetch "/api/v1/auth/me"

  case "$FETCH_STATUS" in
    200 | 401 | 403 | 404)
      info "API proxy ok (GET /api/v1/auth/me -> $FETCH_STATUS)"
      ;;
    502)
      fail "API proxy health failed: backend returned 502 via Caddy"
      ;;
    000)
      fail "API proxy health failed: request failed (${FETCH_ERROR:-curl error})"
      ;;
    *)
      fail "API proxy health failed: unexpected status $FETCH_STATUS"
      ;;
  esac
}

main() {
  require_cmd curl
  local attempt=1

  while [ "$attempt" -le "$HEALTH_RETRIES" ]; do
    if (
      check_html &&
        check_js_asset "/.lustre/server-hot-reload.js" "Lustre hot reload" "WebSocket" &&
        check_js_asset "/scrumbringer_client/scrumbringer_client.mjs" "Lustre main module" "main" &&
        { [ "$CHECK_API" = "0" ] || check_api_proxy; }
    ); then
      info "healthy: $APP_ORIGIN"
      return 0
    fi

    if [ "$attempt" -lt "$HEALTH_RETRIES" ]; then
      sleep "$HEALTH_SLEEP"
    fi

    attempt=$((attempt + 1))
  done

  return 1
}

main "$@"
