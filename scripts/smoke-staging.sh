#!/usr/bin/env bash
set -euo pipefail

STAGING_BASE_URL=${STAGING_BASE_URL:?STAGING_BASE_URL is required (e.g. https://staging.example.com)}
STAGING_API_URL=${STAGING_API_URL:-""}
SMOKE_EMAIL=${SMOKE_EMAIL:-"admin@example.com"}
SMOKE_PASSWORD=${SMOKE_PASSWORD:-"passwordpassword"}
SMOKE_TASK_ID=${SMOKE_TASK_ID:-"1"}

export BASE_URL="$STAGING_BASE_URL"
export EMAIL="$SMOKE_EMAIL"
export PASSWORD="$SMOKE_PASSWORD"
export TASK_ID="$SMOKE_TASK_ID"

if [ -n "$STAGING_API_URL" ]; then
  export API_URL="$STAGING_API_URL"
fi

bash scripts/smoke-active-task.sh
