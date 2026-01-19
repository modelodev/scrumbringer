-- name: metrics_project_tasks
with task_scope as (
  select
    t.id,
    t.project_id,
    t.type_id,
    tt.name as type_name,
    tt.icon as type_icon,
    t.title,
    coalesce(t.description, '') as description,
    t.priority,
     t.status,
     (
       t.status = 'claimed'
       and exists(
         select 1
         from user_task_work_session ws
         where ws.task_id = t.id and ws.ended_at is null
       )
     ) as is_ongoing,
     coalesce((
       select ws.user_id
       from user_task_work_session ws
       where ws.task_id = t.id and ws.ended_at is null
       order by ws.started_at desc
       limit 1
     ), 0) as ongoing_by_user_id,
     t.created_by,

    coalesce(t.claimed_by, 0) as claimed_by,
    coalesce(to_char(t.claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
    coalesce(to_char(t.completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
    to_char(t.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    t.version
  from tasks t
  join task_types tt on tt.id = t.type_id
  where t.project_id = $1
), event_counts as (
  select
    e.task_id,
    coalesce(sum(case when e.event_type = 'task_claimed' then 1 else 0 end), 0) as claim_count,
    coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0) as release_count,
    coalesce(sum(case when e.event_type = 'task_completed' then 1 else 0 end), 0) as complete_count,
    coalesce(min(case when e.event_type = 'task_claimed' then e.created_at else null end), null) as first_claim_at
  from task_events e
  where e.project_id = $1
    and e.created_at >= now() - ($2 || ' days')::interval
  group by e.task_id
)
select
  ts.id,
  ts.project_id,
  ts.type_id,
  ts.type_name,
  ts.type_icon,
  ts.title,
  ts.description,
  ts.priority,
  ts.status,
  ts.is_ongoing,
  ts.ongoing_by_user_id,
  ts.created_by,
  ts.claimed_by,
  ts.claimed_at,
  ts.completed_at,
  ts.created_at,
  ts.version,
  coalesce(ec.claim_count, 0) as claim_count,
  coalesce(ec.release_count, 0) as release_count,
  coalesce(ec.complete_count, 0) as complete_count,
  coalesce(to_char(ec.first_claim_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as first_claim_at
from task_scope ts
left join event_counts ec on ec.task_id = ts.id
order by ts.created_at desc;
