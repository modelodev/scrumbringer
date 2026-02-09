#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=${ROOT_DIR:-"$(pwd)"}
GLEAM_BIN=${GLEAM_BIN:-"gleam"}

echo "[build] server"
(
  cd "$ROOT_DIR/apps/server"
  "$GLEAM_BIN" build
)

echo "[build] client"
(
  cd "$ROOT_DIR/apps/client"
  "$GLEAM_BIN" build
)

echo "[build] shared"
(
  cd "$ROOT_DIR/shared"
  "$GLEAM_BIN" build
)

echo "[build] birl"
(
  cd "$ROOT_DIR/packages/birl"
  "$GLEAM_BIN" build
)

echo "[build] client dist"
(
  cd "$ROOT_DIR/apps/client"
  "$GLEAM_BIN" run -m lustre/dev build
)

echo "Build complete"
