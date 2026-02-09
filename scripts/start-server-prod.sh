#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=${ROOT_DIR:-"/opt/scrumbringer"}
GLEAM_BIN=${GLEAM_BIN:-"gleam"}

export DATABASE_URL=${DATABASE_URL:?DATABASE_URL is required}
export SB_SECRET_KEY_BASE=${SB_SECRET_KEY_BASE:?SB_SECRET_KEY_BASE is required}
export SB_PORT=${SB_PORT:-8000}
export SB_COOKIE_SECURE=${SB_COOKIE_SECURE:-true}
export SB_DB_POOL_SIZE=${SB_DB_POOL_SIZE:-20}
export SB_DB_WAIT_ATTEMPTS=${SB_DB_WAIT_ATTEMPTS:-60}
export SB_DB_WAIT_MS=${SB_DB_WAIT_MS:-50}
export SB_DB_WAIT_QUERY_TIMEOUT_MS=${SB_DB_WAIT_QUERY_TIMEOUT_MS:-15000}

cd "$ROOT_DIR/apps/server"
exec "$GLEAM_BIN" run -m main
