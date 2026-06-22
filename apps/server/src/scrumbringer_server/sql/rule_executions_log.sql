-- name: rule_executions_log
-- Log a rule execution for idempotency tracking and metrics.
insert into rule_executions (
  rule_id,
  event_key,
  task_id,
  card_id,
  outcome,
  suppression_reason,
  user_id,
  template_id,
  template_version,
  created_task_id
)
values (
  $1,
  $2,
  nullif($3, 0),
  nullif($4, 0),
  $5,
  nullif($6, ''),
  nullif($7, 0),
  nullif($8, 0),
  nullif($9, 0),
  nullif($10, 0)
)
on conflict do nothing
returning
  id,
  rule_id,
  event_key,
  coalesce(task_id, 0) as task_id,
  coalesce(card_id, 0) as card_id,
  outcome,
  coalesce(suppression_reason, '') as suppression_reason,
  coalesce(user_id, 0) as user_id,
  coalesce(template_id, 0) as template_id,
  coalesce(template_version, 0) as template_version,
  coalesce(created_task_id, 0) as created_task_id,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
