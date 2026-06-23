-- name: rule_executions_count
-- Count total executions for a rule (for pagination).
select count(*)::int as total
from rule_executions
where rule_id = $1
    and outcome = 'applied'
    and (created_at at time zone 'utc') >= ($2::timestamp)::date
    and (created_at at time zone 'utc') < (($3::timestamp)::date + interval '1 day');
