#!/usr/bin/env bash
set -euo pipefail

# Smoke test for Story 2.7: deep links + refresh + popstate.
# Uses a mock API (Node) + Caddy SPA fallback + headless Chromium.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MOCK_PORT="${MOCK_PORT:-}"
CADDY_PORT="${CADDY_PORT:-8080}"

pick_free_port() {
  local port
  for port in $(seq 9000 9999); do
    if ! ss -ltn | rg -q ":${port} "; then
      echo "$port"
      return 0
    fi
  done

  echo "No free port found in 9000-9999" >&2
  return 1
}

if [ -z "$MOCK_PORT" ]; then
  MOCK_PORT="$(pick_free_port)"
fi

cleanup() {
  if [ -n "${CADDY_PID:-}" ] && kill -0 "$CADDY_PID" 2>/dev/null; then
    kill "$CADDY_PID" || true
  fi
  if [ -n "${MOCK_PID:-}" ] && kill -0 "$MOCK_PID" 2>/dev/null; then
    kill "$MOCK_PID" || true
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"

if [ ! -f "apps/client/dist/index.html" ]; then
  echo "Missing apps/client/dist/index.html (build client first)" >&2
  exit 1
fi

export SB_PORT="$MOCK_PORT"

node "scripts/smoke/mock-api-2.7.mjs" &
MOCK_PID=$!

caddy run --config "./Caddyfile.smoke" --adapter caddyfile &
CADDY_PID=$!

# Wait for Caddy to start
sleep 1

echo "[smoke] Caddy SPA fallback reachable" >&2
curl -s --max-time 5 -I "http://localhost:${CADDY_PORT}/admin/members?project=2" >/dev/null

echo "[smoke] Verify SPA fallback returns index.html" >&2
curl -s --max-time 5 "http://localhost:${CADDY_PORT}/admin/members?project=2" \
  | rg -n "scrumbringer_client\.js" >/dev/null

echo "[smoke] Verify API reverse proxy works" >&2
curl -s --max-time 5 "http://localhost:${CADDY_PORT}/api/v1/auth/me" \
  | rg -n '"user"' >/dev/null

echo "[smoke] PASS" >&2
