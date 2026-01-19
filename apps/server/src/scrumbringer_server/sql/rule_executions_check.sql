-- name: rule_executions_check
-- Check if a rule has already been executed for a given origin (idempotency).
select
  id,
  outcome,
  coalesce(suppression_reason, '') as suppression_reason
from rule_executions
where rule_id = $1
  and origin_type = $2
  and origin_id = $3
limit 1;
