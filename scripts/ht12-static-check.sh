#!/usr/bin/env bash
set -euo pipefail

# Static HT-12 guards that do not need a running database. These checks cover
# regressions that would turn claim/release/complete back into generic database
# errors on schemas where task lifecycle state is stored in execution_state.

forbidden_status_write="status[[:space:]]*=[[:space:]]*'(claimed|available|completed)'"
lifecycle_files=(
  "apps/server/src/scrumbringer_server/sql/tasks_claim.sql"
  "apps/server/src/scrumbringer_server/sql/tasks_release.sql"
  "apps/server/src/scrumbringer_server/sql/tasks_complete.sql"
  "apps/server/src/scrumbringer_server/sql/tasks_release_all.sql"
  "apps/server/src/scrumbringer_server/sql.gleam"
)

failures=0

if grep -REn "TASK_MILESTONE_INHERITED_FROM_CARD|INVALID_MOVE_POOL_TO_MILESTONE" \
  apps/server/src apps/client/src shared/src >/dev/null; then
  echo "ht12-static:active_code:legacy_milestone_error_codes=found"
  grep -REn "TASK_MILESTONE_INHERITED_FROM_CARD|INVALID_MOVE_POOL_TO_MILESTONE" \
    apps/server/src apps/client/src shared/src || true
  failures=1
else
  echo "ht12-static:active_code:legacy_milestone_error_codes=ok"
fi

for file in "${lifecycle_files[@]}"; do
  if grep -En "$forbidden_status_write" "$file" >/dev/null; then
    echo "ht12-static:${file}:legacy_status_write=found"
    grep -En "$forbidden_status_write" "$file" || true
    failures=1
  else
    echo "ht12-static:${file}:legacy_status_write=ok"
  fi
done

if grep -En "\bt\.status\b" apps/server/src/scrumbringer_server/use_case/metrics_db.gleam >/dev/null; then
  echo "ht12-static:metrics_db:direct_task_status_read=found"
  grep -En "\bt\.status\b" apps/server/src/scrumbringer_server/use_case/metrics_db.gleam || true
  failures=1
else
  echo "ht12-static:metrics_db:direct_task_status_read=ok"
fi

if grep -En "\('tasks', 'status'\)" scripts/ht12-db-schema-check.sh >/dev/null; then
  echo "ht12-static:db_schema_check:legacy_status_required=found"
  grep -En "\('tasks', 'status'\)" scripts/ht12-db-schema-check.sh || true
  failures=1
else
  echo "ht12-static:db_schema_check:legacy_status_required=ok"
fi

if grep -Eq "target\.execution_state = 'active'" apps/server/src/scrumbringer_server/sql/tasks_claim.sql \
  && grep -Eq "execution_state = 'closed'" apps/server/src/scrumbringer_server/sql/tasks_claim.sql; then
  echo "ht12-static:tasks_claim:card_claimability=ok"
else
  echo "ht12-static:tasks_claim:card_claimability=missing"
  failures=1
fi

if grep -Eq "task_dependencies:claim_join_shape" scripts/ht12-db-schema-check.sh \
  && grep -Eq "column:tasks\.pool_lifetime_s\.default_not_null" scripts/ht12-db-schema-check.sh \
  && grep -Eq "column:audit_events\.task_id\.nullable" scripts/ht12-db-schema-check.sh; then
  echo "ht12-static:db_schema_check:claim_prerequisites=ok"
else
  echo "ht12-static:db_schema_check:claim_prerequisites=missing"
  failures=1
fi

if grep -Eq "require_migrated_database" scripts/dev-hot.sh \
  && grep -Eq "ht12-db-schema-check\.sh" scripts/dev-hot.sh; then
  echo "ht12-static:dev_hot:schema_preflight=ok"
else
  echo "ht12-static:dev_hot:schema_preflight=missing"
  failures=1
fi

if grep -Eq "pool_open_after" shared/src/api/cards/contracts.gleam \
  && grep -Eq "healthy_pool_limit" shared/src/api/cards/contracts.gleam \
  && grep -Eq "pool_health" shared/src/api/cards/contracts.gleam \
  && grep -Eq "HierarchyActivationPoolSaturated" apps/client/src/scrumbringer_client/i18n/text.gleam; then
  echo "ht12-static:card_action_response:pool_health=ok"
else
  echo "ht12-static:card_action_response:pool_health=missing"
  failures=1
fi

if grep -Eq "pool_open_after" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "exceeds_healthy_limit" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "CARD_HAS_CLAIMED_DESCENDANT" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "close-root-with-claimed-descendant" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:pool_health_and_close_block=ok"
else
  echo "ht12-static:sweep:pool_health_and_close_block=missing"
  failures=1
fi

if grep -Eq "/dependencies" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "CONFLICT_BLOCKED" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "dependency-cycle-rejected" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "dependency-cross-project-rejected" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "dependency-removed-delete" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:task_dependencies=ok"
else
  echo "ht12-static:sweep:task_dependencies=missing"
  failures=1
fi

if grep -Eq "Active card immediate Pool task" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "active-context-task-get" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "data\.task\.status" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq '"available"' scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "active-context-task-claim" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:active_card_contextual_task=ok"
else
  echo "ht12-static:sweep:active_card_contextual_task=missing"
  failures=1
fi

if grep -Eq "json_expect_error_code" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "TASK_NOT_CLAIMABLE" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "TASK_HAS_OPERATIONAL_HISTORY" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "CONFLICT_HAS_CHILD_CARDS" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "CARD_HAS_CHILD_CARDS" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "CARD_HAS_OPERATIONAL_HISTORY" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "TASK_PARENT_CARD_CONFLICT" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:explicit_error_codes=ok"
else
  echo "ht12-static:sweep:explicit_error_codes=missing"
  failures=1
fi

if grep -Eq "Close available-only branch task" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "close-available-branch" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "close-available-task" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "data\.task\.status" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq '"completed"' scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "close-available-leaf-card" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:close_available_branch=ok"
else
  echo "ht12-static:sweep:close_available_branch=missing"
  failures=1
fi

if grep -Eq "assert_active_nav" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "\.nav-link\.active\[aria-current=\"page\"\]" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "depth-1-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "nav-cards" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:sidebar_dom_active=ok"
else
  echo "ht12-static:sweep:sidebar_dom_active=missing"
  failures=1
fi

if grep -Eq "click_and_capture_nav_route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "sidebar-click-cards" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "sidebar-click-pool" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "assert_url_contains" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:sidebar_click_navigation=ok"
else
  echo "ht12-static:sweep:sidebar_click_navigation=missing"
  failures=1
fi

if grep -Eq "seed_and_exercise_automation_api" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "/task-templates" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "/workflows" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "/rules" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "task_created" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "task_claimed" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "task_released" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "task_completed" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "card_activated" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "card_closed" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "/rule-executions" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "automation_origin" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "automation-invalid-missing-template-rule" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "created-noncascade" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "AUTOMATION_CREATED_TASK_ID" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:automation_execution_trace=ok"
else
  echo "ht12-static:sweep:automation_execution_trace=missing"
  failures=1
fi

if grep -Eq "capabilities-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "people-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "kanban-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "automations-engines-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "automations-templates-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "automations-executions-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "automation-created-task-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "card-scope-capabilities-route" scripts/ht12-agent-browser-sweep.sh \
  && grep -Eq "card-scope-people-route" scripts/ht12-agent-browser-sweep.sh; then
  echo "ht12-static:sweep:fin_refactor_routes=ok"
else
  echo "ht12-static:sweep:fin_refactor_routes=missing"
  failures=1
fi

if grep -Eq "closed_by_ancestor" apps/server/test/cards_http_test.gleam; then
  echo "ht12-static:cards_http:closed_by_ancestor_reason=ok"
else
  echo "ht12-static:cards_http:closed_by_ancestor_reason=missing"
  failures=1
fi

if grep -Eq "create_context_blocks_submit" apps/client/src/scrumbringer_client/features/pool/create_dialog.gleam \
  && grep -Eq "card_has_child_cards" apps/client/src/scrumbringer_client/features/pool/create_dialog.gleam \
  && grep -Eq "TaskCreateRootPoolHint" apps/client/src/scrumbringer_client/features/pool/create_dialog.gleam \
  && grep -Eq "TaskCreateActiveCardHint" apps/client/src/scrumbringer_client/features/pool/create_dialog.gleam \
  && ! grep -Eq "on_card_id_changed|task-create-card" apps/client/src/scrumbringer_client/features/pool/create_dialog.gleam \
  && ! grep -Eq "Root Pool task|Closed cards cannot receive new tasks|This task will enter the Pool|Selected card is not available" apps/client/src/scrumbringer_client/features/pool/create_dialog.gleam; then
  echo "ht12-static:create_dialog:contextual_task_creation=ok"
else
  echo "ht12-static:create_dialog:contextual_task_creation=missing"
  failures=1
fi

if grep -Eq "pub type DisabledReason" apps/client/src/scrumbringer_client/features/cards/policy.gleam \
  && grep -Eq "ClosedCardCannotReceiveChildren" apps/client/src/scrumbringer_client/features/cards/policy.gleam \
  && grep -Eq "CardHasOperationalHistory" apps/client/src/scrumbringer_client/features/cards/policy.gleam \
  && grep -Eq "disabled_reason_label" apps/client/src/scrumbringer_client/components/card_show.gleam \
  && grep -Eq "CardClosedCannotReceiveChildren" apps/client/src/scrumbringer_client/components/card_show.gleam \
  && grep -Eq "ActivateHierarchyManagerOnly" apps/client/src/scrumbringer_client/components/card_show.gleam \
  && ! grep -Eq "Only project managers can activate a card hierarchy|Closed cards cannot receive new children|Cannot delete: has operational history|Mover a" apps/client/src/scrumbringer_client/components/card_show.gleam apps/client/src/scrumbringer_client/features/cards/policy.gleam; then
  echo "ht12-static:card_actions:i18n_typed_blockers=ok"
else
  echo "ht12-static:card_actions:i18n_typed_blockers=missing"
  failures=1
fi

if grep -Eq "can_delete_without_visible_history" apps/client/src/scrumbringer_client/features/tasks/mutation_update.gleam \
  && grep -Eq "task_state\.Available, 0 -> True" apps/client/src/scrumbringer_client/features/tasks/mutation_update.gleam \
  && grep -Eq "MemberDeleteTaskClicked" apps/client/test/tasks_mutation_update_test.gleam \
  && grep -Eq "claimed_task_does_not_submit|blocked_task_does_not_submit" apps/client/test/tasks_mutation_update_test.gleam; then
  echo "ht12-static:task_delete:client_guards_operational_history=ok"
else
  echo "ht12-static:task_delete:client_guards_operational_history=missing"
  failures=1
fi

if grep -Eq 'ProjectDepthName\(1, "Initiative", "Initiatives"\)' shared/src/domain/project/project_codec.gleam \
  && grep -Eq 'ProjectDepthName\(2, "Feature", "Features"\)' shared/src/domain/project/project_codec.gleam \
  && grep -Eq "\(1, 'Initiative', 'Initiatives'\)" apps/server/src/scrumbringer_server/sql/projects_create.sql \
  && grep -Eq "\(2, 'Feature', 'Features'\)" apps/server/src/scrumbringer_server/sql/projects_create.sql \
  && grep -Eq "20260620107000" scripts/ht12-db-schema-check.sh; then
  echo "ht12-static:project_depth_defaults=ok"
else
  echo "ht12-static:project_depth_defaults=missing"
  failures=1
fi

exit "$failures"
