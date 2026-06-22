-- name: rule_executions_count
-- Count total executions for a rule (for pagination).
select count(*)::int as total
from rule_executions
where rule_id = $1
    and created_at >= ($2::timestamp)::date
    and created_at < (($3::timestamp)::date + interval '1 day');
