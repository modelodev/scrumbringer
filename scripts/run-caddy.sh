#!/usr/bin/env bash
set -euo pipefail

# Start Caddy with SB_PORT exported from apps/server/.env.
# Note: avoid exporting secrets; we only export SB_PORT.
# Uses ./Caddyfile if present, otherwise ./Caddyfile.example.

SB_PORT="$(grep -E '^SB_PORT=' apps/server/.env | head -n 1 | cut -d= -f2-)"
export SB_PORT

CONFIG="./Caddyfile"
if [ ! -f "$CONFIG" ]; then
  CONFIG="./Caddyfile.example"
fi

if [ ! -f "$CONFIG" ]; then
  echo "Caddy config not found: expected ./Caddyfile or ./Caddyfile.example" >&2
  exit 1
fi

exec caddy run --config "$CONFIG"
