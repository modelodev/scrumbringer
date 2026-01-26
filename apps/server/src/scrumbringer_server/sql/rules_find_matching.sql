-- name: rules_find_matching
-- Find active rules that match a state change event.
-- For task events, filters by task_type_id if specified.
-- For card events, task_type_id filter is ignored.
-- Params: $1=resource_type, $2=to_state, $3=project_id, $4=org_id, $5=task_type_id
select
  r.id,
  r.workflow_id,
  r.name,
  coalesce(r.goal, '') as goal,
  r.resource_type,
  coalesce(r.task_type_id, 0) as task_type_id,
  r.to_state,
  r.active,
  to_char(r.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  w.org_id as workflow_org_id,
  coalesce(w.project_id, 0) as workflow_project_id
from rules r
join workflows w on w.id = r.workflow_id
where r.active = true
  and w.active = true
  and r.resource_type = $1
  and r.to_state = $2
  -- Scope: org-wide workflows apply to all projects in org
  -- Project-scoped workflows only apply to their project
  and w.org_id = $4
  and (w.project_id is null or w.project_id = $3)
  -- Task type filter: only for task events, ignore if task_type_id is null
  and (
    $1 != 'task'
    or r.task_type_id is null
    or $5 <= 0
    or r.task_type_id = $5
  )
order by w.project_id nulls last, r.id;
