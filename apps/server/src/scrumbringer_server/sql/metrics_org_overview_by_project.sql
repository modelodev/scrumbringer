-- name: metrics_org_overview_by_project
select
  p.id as project_id,
  p.name as project_name,
  coalesce(sum(case when e.event_type = 'task_claimed' then 1 else 0 end), 0) as claimed_count,
  coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0) as released_count,
  coalesce(sum(case when e.event_type = 'task_completed' then 1 else 0 end), 0) as completed_count
from projects p
left join task_events e
  on e.project_id = p.id
  and e.created_at >= now() - ($2 || ' days')::interval
where p.org_id = $1
group by p.id, p.name
order by p.name asc;
