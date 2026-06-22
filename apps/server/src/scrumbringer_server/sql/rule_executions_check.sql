-- name: rule_executions_check
-- Check if a rule has already been executed for a given event (idempotency).
select
  id,
  outcome,
  coalesce(suppression_reason, '') as suppression_reason
from rule_executions
where rule_id = $1
  and event_key = $2
limit 1;
