-- name: rule_executions_check
-- Check if a rule has already been executed for a given target (idempotency).
select
  id,
  outcome,
  coalesce(suppression_reason, '') as suppression_reason
from rule_executions
where rule_id = $1
  and (
    (task_id is not null and task_id = nullif($2, 0))
    or (card_id is not null and card_id = nullif($3, 0))
  )
limit 1;
