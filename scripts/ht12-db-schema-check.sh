#!/usr/bin/env bash
set -euo pipefail

# HT-12 database schema diagnostic.
#
# Prints a compact read-only report for the Card tree + Task leaves schema
# invariants that directly affect activation, Pool visibility, task claim, and
# delete-with-history behavior.

DATABASE_URL="${DATABASE_URL:-postgres://scrumbringer:scrumbringer@localhost:5433/scrumbringer_dev?sslmode=disable}"

EXPECTED_MIGRATIONS=(
  "20260619120000"
  "20260620100000"
  "20260620101000"
  "20260620102000"
  "20260620103000"
  "20260620104000"
  "20260620105000"
  "20260620106000"
  "20260620107000"
  "20260620108000"
  "20260623121000"
  "20260623122000"
)

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is not available; skipping database schema check"
  exit 0
fi

if ! psql "$DATABASE_URL" --no-align --tuples-only --quiet --set ON_ERROR_STOP=1 \
  --command "SELECT 1;" >/dev/null 2>&1; then
  echo "database:connection=unreachable"
  psql "$DATABASE_URL" --no-align --tuples-only --quiet --set ON_ERROR_STOP=1 \
    --command "SELECT 1;" || true
  exit 2
fi

report_file="$(mktemp "${TMPDIR:-/tmp}/ht12-db-schema-check.XXXXXX")"
trap 'rm -f "$report_file"' EXIT

psql "$DATABASE_URL" --no-align --tuples-only --quiet --set ON_ERROR_STOP=1 >"$report_file" <<'SQL'
WITH expected_tables(name) AS (
  VALUES
    ('audit_events'),
    ('automation_config_events'),
    ('cards'),
    ('project_card_depth_names'),
    ('project_settings'),
    ('task_dependencies'),
    ('tasks')
),
expected_columns(table_name, column_name) AS (
  VALUES
    ('audit_events', 'actor_user_id'),
    ('audit_events', 'card_id'),
    ('audit_events', 'created_at'),
    ('audit_events', 'event_type'),
    ('audit_events', 'org_id'),
    ('audit_events', 'payload_json'),
    ('audit_events', 'project_id'),
    ('audit_events', 'task_id'),
    ('automation_config_events', 'actor_user_id'),
    ('automation_config_events', 'change_type'),
    ('automation_config_events', 'created_at'),
    ('automation_config_events', 'entity_id'),
    ('automation_config_events', 'entity_type'),
    ('automation_config_events', 'org_id'),
    ('automation_config_events', 'payload_json'),
    ('automation_config_events', 'project_id'),
    ('cards', 'activation_source_card_id'),
    ('cards', 'activated_at'),
    ('cards', 'activated_by'),
    ('cards', 'color'),
    ('cards', 'closed_at'),
    ('cards', 'closed_by'),
    ('cards', 'closed_by_kind'),
    ('cards', 'closed_reason'),
    ('cards', 'execution_state'),
    ('cards', 'parent_card_id'),
    ('tasks', 'card_id'),
    ('tasks', 'claimed_at'),
    ('tasks', 'claimed_by'),
    ('tasks', 'claimed_mode'),
    ('tasks', 'closed_at'),
    ('tasks', 'created_from_rule_id'),
    ('tasks', 'due_date'),
    ('tasks', 'execution_state'),
    ('tasks', 'last_entered_pool_at'),
    ('tasks', 'pool_lifetime_s'),
    ('tasks', 'type_id'),
    ('tasks', 'version'),
    ('task_dependencies', 'depends_on_task_id'),
    ('task_dependencies', 'task_id'),
    ('task_types', 'icon'),
    ('task_types', 'name')
),
table_checks AS (
  SELECT
    'table:' || name AS check_name,
    CASE WHEN to_regclass('public.' || name) IS NULL THEN 'missing' ELSE 'ok' END AS result
  FROM expected_tables
),
column_checks AS (
  SELECT
    'column:' || table_name || '.' || column_name AS check_name,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = expected_columns.table_name
          AND column_name = expected_columns.column_name
      ) THEN 'ok'
      ELSE 'missing'
    END AS result
  FROM expected_columns
),
column_property_checks AS (
  SELECT
    check_name,
    CASE WHEN ok THEN 'ok' ELSE 'missing' END AS result
  FROM (
    VALUES
      (
        'column:audit_events.task_id.nullable',
        EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'audit_events'
            AND column_name = 'task_id'
            AND is_nullable = 'YES'
        )
      ),
      (
        'column:cards.execution_state.default_not_null',
        EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'cards'
            AND column_name = 'execution_state'
            AND is_nullable = 'NO'
            AND column_default LIKE '%draft%'
        )
      ),
      (
        'column:tasks.pool_lifetime_s.default_not_null',
        EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'tasks'
            AND column_name = 'pool_lifetime_s'
            AND is_nullable = 'NO'
            AND column_default LIKE '%0%'
        )
      ),
      (
        'column:project_settings.healthy_pool_limit.default_not_null',
        EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'project_settings'
            AND column_name = 'healthy_pool_limit'
            AND is_nullable = 'NO'
            AND column_default LIKE '%20%'
        )
      )
  ) AS properties(check_name, ok)
),
legacy_checks AS (
  SELECT
    'legacy:task_events_removed' AS check_name,
    CASE WHEN to_regclass('public.task_events') IS NULL THEN 'ok' ELSE 'present' END AS result
),
audit_event_type_checks AS (
  SELECT
    'audit:event_type_claim_and_card_events' AS check_name,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public.audit_events')
          AND pg_get_constraintdef(oid) LIKE '%task_claimed%'
          AND pg_get_constraintdef(oid) LIKE '%card_activated%'
          AND pg_get_constraintdef(oid) LIKE '%card_closed%'
      ) THEN 'ok'
      ELSE 'missing'
    END AS result
),
dependency_checks AS (
  SELECT
    'task_dependencies:claim_join_shape' AS check_name,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public.task_dependencies')
          AND conname = 'task_dependencies_task_id_fkey'
      )
      AND EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public.task_dependencies')
          AND conname = 'task_dependencies_depends_on_task_id_fkey'
      ) THEN 'ok'
      ELSE 'missing'
    END AS result
),
project_default_depth_checks AS (
  SELECT
    'project_card_depth_names:stale_generated_defaults' AS check_name,
    CASE
      WHEN NOT EXISTS (
        SELECT 1
        FROM public.project_card_depth_names
        WHERE (depth = 1 AND singular_name = 'Card' AND plural_name = 'Cards')
           OR (depth = 2 AND singular_name = 'Card' AND plural_name = 'Cards')
           OR (depth = 2 AND singular_name = 'Initiative' AND plural_name = 'Initiatives')
      ) THEN 'ok'
      ELSE 'stale'
    END AS result
),
card_lifecycle_checks AS (
  SELECT
    'cards:lifecycle_constraints' AS check_name,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public.cards')
          AND conname = 'cards_execution_state_check'
      )
      AND EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public.cards')
          AND conname = 'cards_closed_reason_check'
          AND pg_get_constraintdef(oid) LIKE '%rollup%'
          AND pg_get_constraintdef(oid) LIKE '%manually_closed%'
      ) THEN 'ok'
      ELSE 'missing'
    END AS result
),
task_lifecycle_checks AS (
  SELECT
    'tasks:lifecycle_constraints' AS check_name,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public.tasks')
          AND conname = 'tasks_execution_state_check'
      )
      AND EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public.tasks')
          AND conname = 'tasks_closed_reason_check'
          AND pg_get_constraintdef(oid) LIKE '%closed_by_ancestor%'
      )
      AND EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public.tasks')
          AND conname = 'tasks_pool_lifetime_non_negative'
      ) THEN 'ok'
      ELSE 'missing'
    END AS result
),
automation_history_fk_checks AS (
  SELECT
    check_name,
    CASE WHEN ok THEN 'ok' ELSE 'missing' END AS result
  FROM (
    VALUES
      (
        'automation_history:rule_executions_rule_restrict',
        EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conrelid = to_regclass('public.rule_executions')
            AND conname = 'rule_executions_rule_id_fkey'
            AND confdeltype = 'r'
        )
      ),
      (
        'automation_history:tasks_created_from_rule_restrict',
        EXISTS (
          SELECT 1
          FROM pg_constraint
          WHERE conrelid = to_regclass('public.tasks')
            AND conname = 'tasks_created_from_rule_id_fkey'
            AND confdeltype = 'r'
        )
      )
  ) AS properties(check_name, ok)
)
SELECT check_name || '=' || result
FROM (
  SELECT * FROM table_checks
  UNION ALL
  SELECT * FROM column_checks
  UNION ALL
  SELECT * FROM column_property_checks
  UNION ALL
  SELECT * FROM legacy_checks
  UNION ALL
  SELECT * FROM audit_event_type_checks
  UNION ALL
  SELECT * FROM dependency_checks
  UNION ALL
  SELECT * FROM project_default_depth_checks
  UNION ALL
  SELECT * FROM card_lifecycle_checks
  UNION ALL
  SELECT * FROM task_lifecycle_checks
  UNION ALL
  SELECT * FROM automation_history_fk_checks
) checks
ORDER BY check_name;
SQL

schema_migrations_exists="$(
  psql "$DATABASE_URL" --no-align --tuples-only --quiet --set ON_ERROR_STOP=1 \
    --command "SELECT CASE WHEN to_regclass('public.schema_migrations') IS NULL THEN 'missing' ELSE 'ok' END;"
)"

for version in "${EXPECTED_MIGRATIONS[@]}"; do
  if [ "$schema_migrations_exists" != "ok" ]; then
    echo "migration:${version}=schema_migrations_missing" >>"$report_file"
  elif psql "$DATABASE_URL" --no-align --tuples-only --quiet --set ON_ERROR_STOP=1 \
    --command "SELECT 1 FROM public.schema_migrations WHERE version::text = '${version}' LIMIT 1;" \
    | grep -qx "1"; then
    echo "migration:${version}=ok" >>"$report_file"
  else
    echo "migration:${version}=missing" >>"$report_file"
  fi
done

cat "$report_file"

if grep -Ev '=ok$' "$report_file" >/dev/null; then
  exit 1
fi
