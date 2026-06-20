#!/usr/bin/env bash
set -euo pipefail

# HT-12 browser sweep harness.
#
# This script verifies that the local app/API are reachable, seeds a concrete
# Card tree + Task leaves scenario through the public API, exercises core
# lifecycle mutations, then opens the same data in agent-browser for responsive
# UI evidence.

BASE_URL="${BASE_URL:-http://127.0.0.1:8443}"
BASE_URL="${BASE_URL%/}"
API_BASE="${API_BASE:-http://127.0.0.1:8000}"
API_BASE="${API_BASE%/}"
OUT_DIR="${OUT_DIR:-/tmp/scrumbringer-ht12-sweep-$(date +%Y%m%d%H%M%S)}"

SWEEP_EMAIL="${SWEEP_EMAIL:-admin@example.com}"
SWEEP_PASSWORD="${SWEEP_PASSWORD:-passwordpassword}"
SWEEP_LOGIN="${SWEEP_LOGIN:-1}"
SWEEP_DB_CHECK="${SWEEP_DB_CHECK:-1}"
SWEEP_NAME="${SWEEP_NAME:-HT12$(date +%H%M%S)}"
SWEEP_BROWSER_SESSION="${SWEEP_BROWSER_SESSION:-ht12-sweep-$$}"
SWEEP_BROWSER_CLEANUP="${SWEEP_BROWSER_CLEANUP:-1}"
COOKIE_JAR=""

log() {
  printf '[ht12-sweep] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

ab() {
  npx agent-browser --session "$SWEEP_BROWSER_SESSION" "$@"
}

cleanup_browser_session() {
  if [ "$SWEEP_BROWSER_CLEANUP" = "1" ]; then
    ab close >/dev/null 2>&1 || true
  fi
}

configure_agent_browser_runtime() {
  if [ -n "${AGENT_BROWSER_EXECUTABLE_PATH:-}" ]; then
    return 0
  fi

  local candidate path
  for candidate in google-chrome-stable google-chrome chromium chromium-browser; do
    path="$(command -v "$candidate" 2>/dev/null || true)"
    if [ -n "$path" ]; then
      export AGENT_BROWSER_EXECUTABLE_PATH="$path"
      log "Using browser executable ${AGENT_BROWSER_EXECUTABLE_PATH}"
      return 0
    fi
  done
}

json_get() {
  local file="$1"
  local expr="$2"
  node -e '
const fs = require("fs");
const root = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const data = root && Object.prototype.hasOwnProperty.call(root, "data") ? root.data : root;
const value = Function("data", "return " + process.argv[2])(data);
if (value === undefined || value === null) process.exit(2);
if (typeof value === "object") {
  console.log(JSON.stringify(value));
} else {
  console.log(String(value));
}
' "$file" "$expr"
}

json_expect() {
  local file="$1"
  local expr="$2"
  local expected="$3"
  local actual
  actual="$(json_get "$file" "$expr")"
  if [ "$actual" != "$expected" ]; then
    printf 'JSON expectation failed for %s: expected %s, got %s\n' "$file" "$expected" "$actual" >&2
    exit 1
  fi
}

json_expect_error_code() {
  local file="$1"
  local expected="$2"

  json_expect "$file" '(data.error && data.error.code) || data.code || (data.data && data.data.error && data.data.error.code)' "$expected"
}

assert_equals() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" != "$expected" ]; then
    printf 'Expectation failed for %s: expected %s, got %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_int_ge() {
  local label="$1"
  local minimum="$2"
  local actual="$3"
  if [ "$actual" -lt "$minimum" ]; then
    printf 'Expectation failed for %s: expected >= %s, got %s\n' "$label" "$minimum" "$actual" >&2
    exit 1
  fi
}

create_task() {
  local project_id="$1"
  local type_id="$2"
  local title="$3"
  local output="$4"

  api_request POST "/api/v1/projects/${project_id}/tasks" "{\"title\":\"${title}\",\"description\":\"sweep task\",\"priority\":3,\"type_id\":${type_id}}" "$output"
  json_get "$output" 'data.task.id'
}

create_task_under_card() {
  local project_id="$1"
  local type_id="$2"
  local card_id="$3"
  local title="$4"
  local output="$5"

  api_request POST "/api/v1/projects/${project_id}/tasks" "{\"title\":\"${title}\",\"description\":\"sweep task\",\"priority\":3,\"type_id\":${type_id},\"card_id\":${card_id}}" "$output"
  json_get "$output" 'data.task.id'
}

csrf_token() {
  awk '$6 == "sb_csrf" { value = $7 } END { print value }' "$COOKIE_JAR"
}

api_request() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"
  local output="$4"
  local expected="${5:-2}"
  local token
  local status
  token="$(csrf_token)"

  if [ -n "$payload" ]; then
    status="$(
      curl -sS \
        -X "$method" \
        -H 'content-type: application/json' \
        -H "x-csrf: $token" \
        -b "$COOKIE_JAR" \
        -c "$COOKIE_JAR" \
        --data "$payload" \
        -w '%{http_code}' \
        -o "$output" \
        "${API_BASE}${path}"
    )"
  else
    status="$(
      curl -sS \
        -X "$method" \
        -H "x-csrf: $token" \
        -b "$COOKIE_JAR" \
        -c "$COOKIE_JAR" \
        -w '%{http_code}' \
        -o "$output" \
        "${API_BASE}${path}"
    )"
  fi

  printf '%s %s -> %s\n' "$method" "$path" "$status" >>"${OUT_DIR}/api-steps.log"
  case "$expected" in
    2)
      case "$status" in
        2*) return 0 ;;
      esac
      ;;
    *)
      if [ "$status" = "$expected" ]; then
        return 0
      fi
      ;;
  esac

  {
    echo "Unexpected HTTP status for ${method} ${path}: ${status}"
    echo "Expected: ${expected}"
    echo "Response body:"
    cat "$output"
  } >&2
  return 1
}

api_login() {
  COOKIE_JAR="${OUT_DIR}/cookies.txt"
  local output="${OUT_DIR}/login.json"
  local status

  log "Logging into API as ${SWEEP_EMAIL}"
  status="$(
    curl -sS \
      -X POST \
      -H 'content-type: application/json' \
      -c "$COOKIE_JAR" \
      --data "{\"email\":\"${SWEEP_EMAIL}\",\"password\":\"${SWEEP_PASSWORD}\"}" \
      -w '%{http_code}' \
      -o "$output" \
      "${API_BASE}/api/v1/auth/login"
  )"
  printf 'POST /api/v1/auth/login -> %s\n' "$status" >"${OUT_DIR}/api-steps.log"

  case "$status" in
    2*) ;;
    *)
      cat >&2 <<EOF
API login failed at ${API_BASE}/api/v1/auth/login with HTTP ${status}.
Response body:
$(cat "$output")
EOF
      exit 1
      ;;
  esac
}

seed_and_exercise_api() {
  log "Seeding HT-12 project through API"
  api_login

  local project_json="${OUT_DIR}/project.json"
  api_request POST /api/v1/projects "{\"name\":\"${SWEEP_NAME}\"}" "$project_json"
  local project_id
  project_id="$(json_get "$project_json" 'data.project.id')"
  printf '%s\n' "$project_id" >"${OUT_DIR}/project-id.txt"

  local types_json="${OUT_DIR}/task-types.json"
  api_request GET "/api/v1/projects/${project_id}/task-types" "" "$types_json"
  local type_id
  type_id="$(json_get "$types_json" 'data.task_types[0].id')"

  local root_a_json="${OUT_DIR}/card-root-a.json"
  local root_b_json="${OUT_DIR}/card-root-b.json"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Root A\",\"description\":\"root\",\"color\":\"blue\"}" "$root_a_json"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Root B\",\"description\":\"root\",\"color\":\"green\"}" "$root_b_json"
  local root_a_id root_b_id
  root_a_id="$(json_get "$root_a_json" 'data.card.id')"
  root_b_id="$(json_get "$root_b_json" 'data.card.id')"

  local feature_a_json="${OUT_DIR}/card-feature-a.json"
  local feature_b_json="${OUT_DIR}/card-feature-b.json"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Feature A\",\"description\":\"feature\",\"parent_card_id\":${root_a_id}}" "$feature_a_json"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Feature B\",\"description\":\"feature\",\"parent_card_id\":${root_a_id}}" "$feature_b_json"
  local feature_a_id feature_b_id
  feature_a_id="$(json_get "$feature_a_json" 'data.card.id')"
  feature_b_id="$(json_get "$feature_b_json" 'data.card.id')"

  local group_a_json="${OUT_DIR}/card-group-a.json"
  local group_b_json="${OUT_DIR}/card-group-b.json"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Task Group A\",\"description\":\"leaf group\",\"parent_card_id\":${feature_a_id}}" "$group_a_json"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Task Group B\",\"description\":\"leaf group\",\"parent_card_id\":${feature_a_id}}" "$group_b_json"
  local group_a_id group_b_id
  group_a_id="$(json_get "$group_a_json" 'data.card.id')"
  group_b_id="$(json_get "$group_b_json" 'data.card.id')"

  api_request POST "/api/v1/projects/${project_id}/tasks" "{\"title\":\"${SWEEP_NAME} invalid task under card group\",\"description\":\"must fail\",\"priority\":3,\"type_id\":${type_id},\"card_id\":${feature_a_id}}" "${OUT_DIR}/invalid-task-card-group.json" 422
  json_expect_error_code "${OUT_DIR}/invalid-task-card-group.json" "CARD_HAS_CHILD_CARDS"
  api_request POST "/api/v1/projects/${project_id}/tasks" "{\"title\":\"${SWEEP_NAME} ambiguous task location\",\"description\":\"must fail\",\"priority\":3,\"type_id\":${type_id},\"card_id\":${group_a_id},\"parent_card_id\":${feature_a_id}}" "${OUT_DIR}/invalid-task-ambiguous-location.json" 422
  json_expect_error_code "${OUT_DIR}/invalid-task-ambiguous-location.json" "TASK_PARENT_CARD_CONFLICT"

  local draft_task_json="${OUT_DIR}/task-draft.json"
  local root_task_json="${OUT_DIR}/task-root.json"
  api_request POST "/api/v1/projects/${project_id}/tasks" "{\"title\":\"${SWEEP_NAME} Prepared draft task\",\"description\":\"prepared\",\"priority\":3,\"type_id\":${type_id},\"card_id\":${group_a_id}}" "$draft_task_json"
  api_request POST "/api/v1/projects/${project_id}/tasks" "{\"title\":\"${SWEEP_NAME} Root pool task\",\"description\":\"root pool\",\"priority\":2,\"type_id\":${type_id}}" "$root_task_json"
  local draft_task_id root_task_id
  draft_task_id="$(json_get "$draft_task_json" 'data.task.id')"
  root_task_id="$(json_get "$root_task_json" 'data.task.id')"

  log "Creating RootPool pressure tasks to exercise healthy Pool saturation"
  local saturation_count=20
  local i
  for i in $(seq 1 "$saturation_count"); do
    api_request POST "/api/v1/projects/${project_id}/tasks" "{\"title\":\"${SWEEP_NAME} Pool pressure ${i}\",\"description\":\"pool pressure\",\"priority\":4,\"type_id\":${type_id}}" "${OUT_DIR}/task-pool-pressure-${i}.json"
  done

  api_request POST "/api/v1/cards/${feature_a_id}/move" "{\"parent_card_id\":${group_a_id}}" "${OUT_DIR}/invalid-move-cycle.json" 422
  api_request POST "/api/v1/cards/${group_b_id}/move" "{\"parent_card_id\":${feature_b_id}}" "${OUT_DIR}/move-compatible.json"

  local empty_card_json="${OUT_DIR}/card-empty-delete.json"
  local history_card_json="${OUT_DIR}/card-history-delete.json"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Empty delete card\",\"description\":\"delete card\"}" "$empty_card_json"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} History card\",\"description\":\"history card\"}" "$history_card_json"
  local empty_card_id history_card_id
  empty_card_id="$(json_get "$empty_card_json" 'data.card.id')"
  history_card_id="$(json_get "$history_card_json" 'data.card.id')"
  api_request DELETE "/api/v1/cards/${empty_card_id}" "" "${OUT_DIR}/delete-empty-card.json"
  api_request DELETE "/api/v1/cards/${root_a_id}" "" "${OUT_DIR}/delete-card-with-children.json" 409
  json_expect_error_code "${OUT_DIR}/delete-card-with-children.json" "CONFLICT_HAS_CHILD_CARDS"
  api_request POST "/api/v1/cards/${history_card_id}/activate" '{}' "${OUT_DIR}/activate-history-card.json"
  api_request DELETE "/api/v1/cards/${history_card_id}" "" "${OUT_DIR}/delete-history-card.json" 409
  json_expect_error_code "${OUT_DIR}/delete-history-card.json" "CARD_HAS_OPERATIONAL_HISTORY"

  local dep_blocked_id dep_blocker_id dep_removed_blocked_id dep_removed_blocker_id dep_cycle_a_id dep_cycle_b_id
  dep_blocked_id="$(create_task "$project_id" "$type_id" "${SWEEP_NAME} Dependency blocked task" "${OUT_DIR}/task-dep-blocked.json")"
  dep_blocker_id="$(create_task "$project_id" "$type_id" "${SWEEP_NAME} Dependency blocker task" "${OUT_DIR}/task-dep-blocker.json")"
  dep_removed_blocked_id="$(create_task "$project_id" "$type_id" "${SWEEP_NAME} Dependency removed blocked task" "${OUT_DIR}/task-dep-removed-blocked.json")"
  dep_removed_blocker_id="$(create_task "$project_id" "$type_id" "${SWEEP_NAME} Dependency removed blocker task" "${OUT_DIR}/task-dep-removed-blocker.json")"
  dep_cycle_a_id="$(create_task "$project_id" "$type_id" "${SWEEP_NAME} Dependency cycle A" "${OUT_DIR}/task-dep-cycle-a.json")"
  dep_cycle_b_id="$(create_task "$project_id" "$type_id" "${SWEEP_NAME} Dependency cycle B" "${OUT_DIR}/task-dep-cycle-b.json")"
  api_request POST "/api/v1/tasks/${dep_blocked_id}/dependencies" "{\"depends_on_task_id\":${dep_blocker_id}}" "${OUT_DIR}/dependency-blocked-on-blocker.json"
  api_request GET "/api/v1/tasks/${dep_blocked_id}/dependencies" "" "${OUT_DIR}/dependency-list-blocked.json"
  json_expect "${OUT_DIR}/dependency-list-blocked.json" 'data.dependencies.length' "1"
  api_request POST "/api/v1/tasks/${dep_blocked_id}/claim" '{"version":1}' "${OUT_DIR}/claim-dependency-blocked.json" 409
  json_expect_error_code "${OUT_DIR}/claim-dependency-blocked.json" "CONFLICT_BLOCKED"
  api_request POST "/api/v1/tasks/${dep_blocker_id}/claim" '{"version":1}' "${OUT_DIR}/claim-dependency-blocker.json"
  api_request POST "/api/v1/tasks/${dep_blocker_id}/complete" '{"version":2}' "${OUT_DIR}/complete-dependency-blocker.json"
  api_request POST "/api/v1/tasks/${dep_blocked_id}/claim" '{"version":1}' "${OUT_DIR}/claim-dependency-unblocked.json"
  api_request POST "/api/v1/tasks/${dep_removed_blocked_id}/dependencies" "{\"depends_on_task_id\":${dep_removed_blocker_id}}" "${OUT_DIR}/dependency-removed-create.json"
  api_request DELETE "/api/v1/tasks/${dep_removed_blocked_id}/dependencies/${dep_removed_blocker_id}" "" "${OUT_DIR}/dependency-removed-delete.json" 204
  api_request POST "/api/v1/tasks/${dep_removed_blocked_id}/claim" '{"version":1}' "${OUT_DIR}/claim-dependency-removed-unblocked.json"
  api_request POST "/api/v1/tasks/${dep_cycle_a_id}/dependencies" "{\"depends_on_task_id\":${dep_cycle_b_id}}" "${OUT_DIR}/dependency-cycle-a-on-b.json"
  api_request POST "/api/v1/tasks/${dep_cycle_b_id}/dependencies" "{\"depends_on_task_id\":${dep_cycle_a_id}}" "${OUT_DIR}/dependency-cycle-rejected.json" 422

  api_request POST "/api/v1/tasks/${draft_task_id}/claim" '{"version":1}' "${OUT_DIR}/claim-draft-before-activation.json" 409
  json_expect_error_code "${OUT_DIR}/claim-draft-before-activation.json" "TASK_NOT_CLAIMABLE"
  api_request POST "/api/v1/cards/${feature_a_id}/activate" '{}' "${OUT_DIR}/activate-feature-a.json"
  json_expect "${OUT_DIR}/activate-feature-a.json" '(data.data || data).pool_impact' "1"
  json_expect "${OUT_DIR}/activate-feature-a.json" '(data.data || data).healthy_pool_limit' "20"
  assert_int_ge "activate-feature-a:pool-open-after" "21" "$(json_get "${OUT_DIR}/activate-feature-a.json" '(data.data || data).pool_open_after')"
  json_expect "${OUT_DIR}/activate-feature-a.json" '(data.data || data).pool_health' "exceeds_healthy_limit"

  local active_context_root_json="${OUT_DIR}/card-active-context-root.json"
  local active_context_leaf_json="${OUT_DIR}/card-active-context-leaf.json"
  local active_context_root_id active_context_leaf_id active_context_task_id
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Active context root\",\"description\":\"active root\"}" "$active_context_root_json"
  active_context_root_id="$(json_get "$active_context_root_json" 'data.card.id')"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Active context task group\",\"description\":\"active leaf\",\"parent_card_id\":${active_context_root_id}}" "$active_context_leaf_json"
  active_context_leaf_id="$(json_get "$active_context_leaf_json" 'data.card.id')"
  api_request POST "/api/v1/cards/${active_context_root_id}/activate" '{}' "${OUT_DIR}/active-context-activate.json"
  json_expect "${OUT_DIR}/active-context-activate.json" '(data.data || data).pool_impact' "0"
  active_context_task_id="$(create_task_under_card "$project_id" "$type_id" "$active_context_leaf_id" "${SWEEP_NAME} Active card immediate Pool task" "${OUT_DIR}/active-context-task.json")"
  api_request GET "/api/v1/tasks/${active_context_task_id}" "" "${OUT_DIR}/active-context-task-get.json"
  json_expect "${OUT_DIR}/active-context-task-get.json" 'data.task.status' "available"
  api_request POST "/api/v1/tasks/${active_context_task_id}/claim" '{"version":1}' "${OUT_DIR}/active-context-task-claim.json"
  api_request POST "/api/v1/tasks/${active_context_task_id}/complete" '{"version":2}' "${OUT_DIR}/active-context-task-complete.json"

  api_request POST "/api/v1/tasks/${draft_task_id}/claim" '{"version":1}' "${OUT_DIR}/claim-draft-task.json"
  api_request POST "/api/v1/cards/${root_a_id}/close" '{}' "${OUT_DIR}/close-root-with-claimed-descendant.json" 409
  json_expect_error_code "${OUT_DIR}/close-root-with-claimed-descendant.json" "CARD_HAS_CLAIMED_DESCENDANT"
  api_request POST "/api/v1/tasks/${draft_task_id}/release" '{"version":2}' "${OUT_DIR}/release-draft-task.json"
  api_request POST "/api/v1/tasks/${draft_task_id}/claim" '{"version":3}' "${OUT_DIR}/claim-again-draft-task.json"
  api_request POST "/api/v1/tasks/${draft_task_id}/complete" '{"version":4}' "${OUT_DIR}/complete-draft-task.json"
  api_request GET "/api/v1/cards/${group_a_id}" "" "${OUT_DIR}/card-group-a-after-complete.json"
  json_expect "${OUT_DIR}/card-group-a-after-complete.json" 'data.card.state' "cerrada"

  local close_root_json="${OUT_DIR}/card-close-available-root.json"
  local close_leaf_json="${OUT_DIR}/card-close-available-leaf.json"
  local close_root_id close_leaf_id close_task_id
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Close available root\",\"description\":\"close available\"}" "$close_root_json"
  close_root_id="$(json_get "$close_root_json" 'data.card.id')"
  api_request POST "/api/v1/projects/${project_id}/cards" "{\"title\":\"${SWEEP_NAME} Close available task group\",\"description\":\"close available leaf\",\"parent_card_id\":${close_root_id}}" "$close_leaf_json"
  close_leaf_id="$(json_get "$close_leaf_json" 'data.card.id')"
  close_task_id="$(create_task_under_card "$project_id" "$type_id" "$close_leaf_id" "${SWEEP_NAME} Close available-only branch task" "${OUT_DIR}/close-available-task-create.json")"
  api_request POST "/api/v1/cards/${close_root_id}/activate" '{}' "${OUT_DIR}/close-available-activate.json"
  json_expect "${OUT_DIR}/close-available-activate.json" '(data.data || data).pool_impact' "1"
  api_request POST "/api/v1/cards/${close_root_id}/close" '{}' "${OUT_DIR}/close-available-branch.json"
  json_expect "${OUT_DIR}/close-available-branch.json" '(data.data || data).pool_impact' "1"
  api_request GET "/api/v1/cards/${close_leaf_id}" "" "${OUT_DIR}/close-available-leaf-card.json"
  json_expect "${OUT_DIR}/close-available-leaf-card.json" 'data.card.state' "cerrada"
  api_request GET "/api/v1/tasks/${close_task_id}" "" "${OUT_DIR}/close-available-task.json"
  json_expect "${OUT_DIR}/close-available-task.json" 'data.task.status' "completed"

  local fresh_task_json="${OUT_DIR}/task-fresh-delete.json"
  api_request POST "/api/v1/projects/${project_id}/tasks" "{\"title\":\"${SWEEP_NAME} Fresh delete task\",\"description\":\"delete me\",\"priority\":4,\"type_id\":${type_id}}" "$fresh_task_json"
  local fresh_task_id
  fresh_task_id="$(json_get "$fresh_task_json" 'data.task.id')"
  api_request DELETE "/api/v1/tasks/${fresh_task_id}" "" "${OUT_DIR}/delete-fresh-task.json"

  api_request POST "/api/v1/tasks/${root_task_id}/claim" '{"version":1}' "${OUT_DIR}/claim-root-task.json"
  api_request DELETE "/api/v1/tasks/${root_task_id}" "" "${OUT_DIR}/delete-claimed-task.json" 409
  json_expect_error_code "${OUT_DIR}/delete-claimed-task.json" "TASK_HAS_OPERATIONAL_HISTORY"

  local cross_project_json="${OUT_DIR}/dependency-cross-project.json"
  api_request POST /api/v1/projects "{\"name\":\"${SWEEP_NAME} Dependency Cross Project\"}" "$cross_project_json"
  local cross_project_id cross_type_id cross_task_id
  cross_project_id="$(json_get "$cross_project_json" 'data.project.id')"
  api_request GET "/api/v1/projects/${cross_project_id}/task-types" "" "${OUT_DIR}/dependency-cross-task-types.json"
  cross_type_id="$(json_get "${OUT_DIR}/dependency-cross-task-types.json" 'data.task_types[0].id')"
  cross_task_id="$(create_task "$cross_project_id" "$cross_type_id" "${SWEEP_NAME} Cross project dependency target" "${OUT_DIR}/task-cross-project-dependency-target.json")"
  api_request POST "/api/v1/tasks/${dep_cycle_a_id}/dependencies" "{\"depends_on_task_id\":${cross_task_id}}" "${OUT_DIR}/dependency-cross-project-rejected.json" 422

  cat >"${OUT_DIR}/scenario.env" <<EOF
PROJECT_ID=${project_id}
TYPE_ID=${type_id}
ROOT_A_ID=${root_a_id}
ROOT_B_ID=${root_b_id}
FEATURE_A_ID=${feature_a_id}
FEATURE_B_ID=${feature_b_id}
GROUP_A_ID=${group_a_id}
GROUP_B_ID=${group_b_id}
DRAFT_TASK_ID=${draft_task_id}
ROOT_TASK_ID=${root_task_id}
SATURATION_TASKS=${saturation_count}
DEP_BLOCKED_TASK_ID=${dep_blocked_id}
DEP_BLOCKER_TASK_ID=${dep_blocker_id}
DEP_REMOVED_BLOCKED_TASK_ID=${dep_removed_blocked_id}
DEP_REMOVED_BLOCKER_TASK_ID=${dep_removed_blocker_id}
ACTIVE_CONTEXT_ROOT_ID=${active_context_root_id}
ACTIVE_CONTEXT_LEAF_ID=${active_context_leaf_id}
ACTIVE_CONTEXT_TASK_ID=${active_context_task_id}
CLOSE_AVAILABLE_ROOT_ID=${close_root_id}
CLOSE_AVAILABLE_LEAF_ID=${close_leaf_id}
CLOSE_AVAILABLE_TASK_ID=${close_task_id}
CROSS_PROJECT_ID=${cross_project_id}
EOF
}

capture_state() {
  local label="$1"
  local width="$2"
  local height="$3"

  log "Capturing ${label} viewport ${width}x${height}"
  ab set viewport "$width" "$height" >/dev/null
  ab wait --load networkidle >/dev/null || true
  ab snapshot -i >"${OUT_DIR}/${label}.snapshot.txt"
  ab screenshot "${OUT_DIR}/${label}.png" >/dev/null
}

try_login() {
  if [ "$SWEEP_LOGIN" != "1" ]; then
    return 0
  fi

  log "Attempting login as ${SWEEP_EMAIL}; continuing if already authenticated"
  ab find label "Email" fill "$SWEEP_EMAIL" >/dev/null 2>&1 \
    || ab find label "Email address" fill "$SWEEP_EMAIL" >/dev/null 2>&1 \
    || ab find label "Correo electrónico" fill "$SWEEP_EMAIL" >/dev/null 2>&1 \
    || {
      ab snapshot -i >"${OUT_DIR}/login-before.snapshot.txt" 2>/dev/null || true
      ab fill @e3 "$SWEEP_EMAIL" >/dev/null 2>&1
    } \
    || return 0
  ab find label "Password" fill "$SWEEP_PASSWORD" >/dev/null 2>&1 \
    || ab find label "Contraseña" fill "$SWEEP_PASSWORD" >/dev/null 2>&1 \
    || ab fill @e4 "$SWEEP_PASSWORD" >/dev/null 2>&1 \
    || return 0
  ab find role button click --name "Sign in" >/dev/null 2>&1 \
    || ab find role button click --name "Login" >/dev/null 2>&1 \
    || ab find role button click --name "Entrar" >/dev/null 2>&1 \
    || ab find role button click --name "Acceso" >/dev/null 2>&1 \
    || ab click @e5 >/dev/null 2>&1 \
    || true
  ab wait --load networkidle >/dev/null || true
}

assert_active_nav() {
  local label="$1"
  local expected_testid="$2"
  local active_count expected_count

  active_count="$(ab get count '.nav-link.active[aria-current="page"]' | tr -d '\r')"
  assert_equals "${label}:active-nav-count" "1" "$active_count"

  expected_count="$(ab get count "[data-testid=\"${expected_testid}\"].nav-link.active[aria-current=\"page\"]" | tr -d '\r')"
  assert_equals "${label}:expected-active-nav" "1" "$expected_count"
}

assert_url_contains() {
  local label="$1"
  local expected="$2"
  local url

  url="$(ab get url | tr -d '\r')"
  case "$url" in
    *"$expected"*) return 0 ;;
  esac

  printf 'Expectation failed for %s:url: expected %s in %s\n' "$label" "$expected" "$url" >&2
  exit 1
}

open_and_capture_route() {
  local label="$1"
  local url="$2"
  local expected_active_testid="${3:-}"
  log "Opening ${label}: ${url}"
  ab open "$url" >/dev/null
  ab wait --load networkidle >/dev/null || true
  if [ -n "$expected_active_testid" ]; then
    assert_active_nav "$label" "$expected_active_testid"
  fi
  ab snapshot -i >"${OUT_DIR}/${label}.snapshot.txt"
  ab screenshot "${OUT_DIR}/${label}.png" >/dev/null
}

click_and_capture_nav_route() {
  local label="$1"
  local nav_testid="$2"
  local expected_url_fragment="$3"

  log "Clicking ${label}: ${nav_testid}"
  ab eval "(function(){const el=document.querySelector('[data-testid=\"${nav_testid}\"]'); if(!el) throw new Error('missing nav ${nav_testid}'); el.click(); return true;})()" >/dev/null
  ab wait --load networkidle >/dev/null || true
  assert_active_nav "$label" "$nav_testid"
  assert_url_contains "$label" "$expected_url_fragment"
  ab snapshot -i >"${OUT_DIR}/${label}.snapshot.txt"
}

capture_db_schema_check() {
  if [ "$SWEEP_DB_CHECK" != "1" ]; then
    return 0
  fi

  log "Running database schema diagnostic"
  if bash scripts/ht12-db-schema-check.sh >"${OUT_DIR}/db-schema-check.txt" 2>&1; then
    return 0
  fi

  {
    echo
    echo "Database schema diagnostic failed. This usually means the database is"
    echo "unreachable or the configured DATABASE_URL points at a non-migrated DB."
  } >>"${OUT_DIR}/db-schema-check.txt"
}

capture_static_check() {
  log "Running static HT-12 lifecycle guards"
  bash scripts/ht12-static-check.sh >"${OUT_DIR}/static-check.txt" 2>&1
}

main() {
  require_cmd curl
  require_cmd npx
  require_cmd node
  trap cleanup_browser_session EXIT

  mkdir -p "$OUT_DIR"
  capture_static_check
  capture_db_schema_check

  log "Checking app at ${BASE_URL}"
  if ! curl -fsS --max-time 5 "$BASE_URL" >/dev/null; then
    cat >&2 <<EOF
Local app is not reachable at ${BASE_URL}.

Expected setup:
  export DATABASE_URL="<reachable migrated postgres URL>"
  dbmate --url "\${DATABASE_URL}" migrate
  DATABASE_URL="\${DATABASE_URL}" scripts/dev-hot.sh

Preflight evidence:
  ${OUT_DIR}

EOF
    exit 1
  fi

  log "Checking API at ${API_BASE}"
  if ! curl -fsS --max-time 5 "${API_BASE}/api/v1/auth/me" >/dev/null; then
    log "API auth/me is not already authenticated; continuing with login probe"
  fi

  seed_and_exercise_api

  if command -v pg_isready >/dev/null 2>&1; then
    pg_isready -h "${PGHOST:-localhost}" -p "${PGPORT:-5433}" \
      -U "${PGUSER:-scrumbringer}" -d "${PGDATABASE:-scrumbringer_dev}" \
      >"${OUT_DIR}/pg_isready.txt" 2>&1 || true
  fi

  configure_agent_browser_runtime
  log "Opening clean browser session"
  ab close >/dev/null 2>&1 || true
  ab open "$BASE_URL" >/dev/null
  ab wait --load networkidle >/dev/null || true

  try_login

  # shellcheck disable=SC1091
  . "${OUT_DIR}/scenario.env"
  ab open "${BASE_URL}/app/pool?project=${PROJECT_ID}&view=pool" >/dev/null
  ab wait --load networkidle >/dev/null || true

  capture_state "desktop" 1440 1000
  capture_state "tablet" 900 1100
  capture_state "mobile" 390 844

  # Route-level evidence for hierarchy navigation. These URLs are formatted by
  # the client router for member Pool/Cards routes.
  ab set viewport 1440 1000 >/dev/null
  open_and_capture_route "pool-route" "${BASE_URL}/app/pool?project=${PROJECT_ID}&view=pool" "nav-pool"
  open_and_capture_route "cards-route" "${BASE_URL}/app/pool?project=${PROJECT_ID}&view=cards" "nav-cards"
  open_and_capture_route "depth-1-route" "${BASE_URL}/app/pool?project=${PROJECT_ID}&view=cards&depth=1" "nav-depth-1"
  open_and_capture_route "depth-2-route" "${BASE_URL}/app/pool?project=${PROJECT_ID}&view=cards&depth=2" "nav-depth-2"
  open_and_capture_route "depth-3-route" "${BASE_URL}/app/pool?project=${PROJECT_ID}&view=cards&depth=3" "nav-depth-3"

  open_and_capture_route "sidebar-click-start" "${BASE_URL}/app/pool?project=${PROJECT_ID}&view=pool" "nav-pool"
  click_and_capture_nav_route "sidebar-click-cards" "nav-cards" "view=cards"
  click_and_capture_nav_route "sidebar-click-depth-1" "nav-depth-1" "depth=1"
  click_and_capture_nav_route "sidebar-click-depth-2" "nav-depth-2" "depth=2"
  click_and_capture_nav_route "sidebar-click-depth-3" "nav-depth-3" "depth=3"
  click_and_capture_nav_route "sidebar-click-pool" "nav-pool" "view=pool"

  ab get url >"${OUT_DIR}/final-url.txt"

  cat <<EOF
[ht12-sweep] Sweep evidence written to:
  ${OUT_DIR}

Seeded project:
  ${SWEEP_NAME}
  ${OUT_DIR}/scenario.env

API lifecycle log:
  ${OUT_DIR}/api-steps.log

Database diagnostic:
  ${OUT_DIR}/db-schema-check.txt

Review the scenario checklist against the captured evidence in:
  docs/validation/ht12-ui-validation.md
EOF
}

main "$@"
