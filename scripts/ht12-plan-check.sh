#!/usr/bin/env bash
set -euo pipefail

# Static guard for the HT-12 user sweep plan. This does not replace the browser
# run; it makes sure the documented scenario keeps covering the critical
# Card tree + Task leaves behaviors while runtime execution is unavailable.

PLAN_FILE="${PLAN_FILE:-docs/validation/ht12-ui-validation.md}"

required_patterns=(
  "Project And Hierarchy Setup"
  "Card Tree Navigation And Moves"
  "Task Creation Contexts"
  "Activation And Pool Impact"
  "healthy_pool_limit"
  "exceeds_healthy_limit"
  "Claim, Release, Complete"
  "CARD_HAS_CLAIMED_DESCENDANT"
  "Delete And Operational History"
  "Task Dependencies"
  "CONFLICT_BLOCKED"
  "circular dependency"
  "dependency across projects"
  "Responsive And Usability Pass"
  "Cards.*active only for the all-cards route"
  "depth route.*active only for its own depth"
  "aria-current"
  "exactly one active nav"
  "prevents mixing child cards and tasks"
  "CARD_HAS_CHILD_CARDS"
  "TASK_PARENT_CARD_CONFLICT"
  "RootPool"
  "Active card.*Pool"
  "No task is auto-claimed"
  "Activation does not activate ancestors"
  "available-only branch"
  "closed_by_ancestor"
  "without a generic database error"
  "TASK_NOT_CLAIMABLE"
  "TASK_HAS_OPERATIONAL_HISTORY"
  "CONFLICT_HAS_CHILD_CARDS"
  "CARD_HAS_OPERATIONAL_HISTORY"
  "no overlapping text"
)

if [ ! -f "$PLAN_FILE" ]; then
  echo "missing plan file: $PLAN_FILE" >&2
  exit 1
fi

missing=0
for pattern in "${required_patterns[@]}"; do
  if grep -Eiq "$pattern" "$PLAN_FILE"; then
    printf 'plan:%s=ok\n' "$pattern"
  else
    printf 'plan:%s=missing\n' "$pattern"
    missing=1
  fi
done

exit "$missing"
