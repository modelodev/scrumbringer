-- name: rule_executions_log
-- Log a rule execution for idempotency tracking and metrics.
insert into rule_executions (rule_id, origin_type, origin_id, outcome, suppression_reason, user_id)
values ($1, $2, $3, $4, nullif($5, ''), $6)
on conflict (rule_id, origin_type, origin_id) do nothing
returning
  id,
  rule_id,
  origin_type,
  origin_id,
  outcome,
  coalesce(suppression_reason, '') as suppression_reason,
  coalesce(user_id, 0) as user_id,
  to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at;
