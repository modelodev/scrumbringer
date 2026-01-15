#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-"https://localhost:8443"}
BASE_URL=${BASE_URL%/}
EMAIL=${EMAIL:-"admin@example.com"}
PASSWORD=${PASSWORD:-"passwordpassword"}
TASK_ID=${TASK_ID:-"1"}

# Some setups proxy `/api/v1/*` correctly for GET but not for POST.
# Provide a direct API fallback to hit the Gleam server without Caddy.
API_URL=${API_URL:-"http://localhost:8000"}
API_URL=${API_URL%/}

echo "BASE_URL=$BASE_URL"
echo "API_URL=$API_URL"

echo "== Login (sets sb_session + sb_csrf cookies) =="

login_and_extract_cookies() {
  local base=$1
  local hdr
  hdr=$(mktemp)

  # NOTE: force HTTP/1.1 because some environments get stuck
  # in an HTTP/2 308 redirect loop.
  local code
  code=$(curl -k -sS --http1.1 \
    -D "$hdr" \
    -o /dev/null \
    -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -X POST "$base/api/v1/auth/login" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

  if [[ "$code" != "200" ]]; then
    rm -f "$hdr"
    return 1
  fi

  CSRF=$(awk 'BEGIN{IGNORECASE=1} /^set-cookie:/ && $0 ~ /sb_csrf=/ { sub(/.*sb_csrf=/, ""); sub(/;.*/, ""); sub(/\r$/, ""); print; exit }' "$hdr")
  SESSION=$(awk 'BEGIN{IGNORECASE=1} /^set-cookie:/ && $0 ~ /sb_session=/ { sub(/.*sb_session=/, ""); sub(/;.*/, ""); sub(/\r$/, ""); print; exit }' "$hdr")

  rm -f "$hdr"

  [[ -n "${CSRF:-}" && -n "${SESSION:-}" ]]
}

CSRF=""
SESSION=""

# Try through BASE_URL first; if it fails, fall back to API_URL.
if login_and_extract_cookies "$BASE_URL"; then
  ACTIVE_API_BASE="$BASE_URL"
else
  echo "Login via BASE_URL failed; falling back to API_URL" >&2
  if ! login_and_extract_cookies "$API_URL"; then
    echo "Login failed via both BASE_URL and API_URL" >&2
    exit 1
  fi
  ACTIVE_API_BASE="$API_URL"
fi

echo "Login OK via: $ACTIVE_API_BASE"

echo "CSRF cookie acquired."

curl_json() {
  local method=$1
  local path=$2
  local data=${3:-}

  local tmp
  tmp=$(mktemp)

  local url="$ACTIVE_API_BASE$path"

  local args=(
    -k -sS --http1.1
    -H "Accept: application/json"
    -H "Cookie: sb_session=$SESSION; sb_csrf=$CSRF"
  )

  if [[ "$method" != "GET" ]]; then
    args+=( -H "X-CSRF: $CSRF" )
  fi

  if [[ -n "$data" ]]; then
    args+=( -H "Content-Type: application/json" -d "$data" )
  fi

  local code
  code=$(curl "${args[@]}" -X "$method" "$url" -o "$tmp" -w "%{http_code}")

  # If Caddy is misrouting POST/GET and returning self-redirects, fall back.
  if [[ "$code" == "308" && "$ACTIVE_API_BASE" != "$API_URL" ]]; then
    ACTIVE_API_BASE="$API_URL"
    url="$ACTIVE_API_BASE$path"
    code=$(curl "${args[@]}" -X "$method" "$url" -o "$tmp" -w "%{http_code}")
  fi

  echo "HTTP $code"
  if [[ -s "$tmp" ]]; then
    sed -e 's/^/  /' "$tmp"
  else
    echo "  <empty body>"
  fi

  rm -f "$tmp"
}

echo "== GET /me/active-task =="
curl_json GET "/api/v1/me/active-task"

echo

echo "== POST /me/active-task/start (task_id=$TASK_ID) =="
curl_json POST "/api/v1/me/active-task/start" "{\"task_id\":$TASK_ID}"

echo

echo "== GET /me/active-task =="
curl_json GET "/api/v1/me/active-task"

echo

echo "== POST /me/active-task/pause =="
curl_json POST "/api/v1/me/active-task/pause"

echo

echo "OK"
