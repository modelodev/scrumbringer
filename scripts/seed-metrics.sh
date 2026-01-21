#!/bin/bash
# Seed the database with test data for metrics validation
#
# Usage:
#   ./scripts/seed-metrics.sh
#
# Prerequisites:
#   - PostgreSQL database running
#   - DATABASE_URL environment variable set (or use apps/server/.env)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$PROJECT_ROOT/apps/server"

# Load .env if DATABASE_URL not set
if [ -z "$DATABASE_URL" ]; then
  if [ -f "$SERVER_DIR/.env" ]; then
    echo "Loading DATABASE_URL from $SERVER_DIR/.env"
    export $(grep -v '^#' "$SERVER_DIR/.env" | xargs)
  else
    echo "ERROR: DATABASE_URL not set and no .env file found"
    exit 1
  fi
fi

echo "=========================================="
echo "  Running Metrics Seed"
echo "=========================================="
echo ""
echo "Database: $DATABASE_URL"
echo ""

cd "$SERVER_DIR"

# Run the standalone seed module
gleam run -m scrumbringer_server/seed

echo ""
echo "=========================================="
echo "  Seed Complete!"
echo "=========================================="
echo ""
echo "You can now:"
echo "  1. Start the server: cd apps/server && gleam run"
echo "  2. Open the app: https://localhost:8443"
echo "  3. Login with: admin@example.com / passwordpassword"
echo "  4. Navigate to:"
echo "     - Admin > Métricas for project metrics"
echo "     - Admin > Métricas de reglas for rule metrics"
echo ""
