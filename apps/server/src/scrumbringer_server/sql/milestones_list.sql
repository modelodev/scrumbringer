-- name: list_milestones_for_project
select
  m.id,
  m.project_id,
  m.name,
  coalesce(m.description, '') as description,
  m.state,
  m.position,
  m.created_by,
  to_char(m.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
  coalesce(to_char(m.activated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as activated_at,
  coalesce(to_char(m.completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
  coalesce(c.cards_total, 0) as cards_total,
  coalesce(c.cards_completed, 0) as cards_completed,
  coalesce(t.tasks_total, 0) as tasks_total,
  coalesce(t.tasks_completed, 0) as tasks_completed
from milestones m
left join lateral (
  select
    count(*) as cards_total,
    count(*) filter (where cd.completed_count = cd.task_count and cd.task_count > 0) as cards_completed
  from (
    select
      c.id,
      count(t.id) as task_count,
      count(*) filter (where t.status = 'completed') as completed_count
    from cards c
    left join tasks t on t.card_id = c.id
    where c.project_id = m.project_id
      and c.milestone_id = m.id
    group by c.id
  ) cd
) c on true
left join lateral (
  select
    count(*) as tasks_total,
    count(*) filter (where t.status = 'completed') as tasks_completed
  from tasks t
  where t.project_id = m.project_id
    and t.card_id is null
    and t.milestone_id = m.id
) t on true
where m.project_id = $1
order by m.position asc, m.created_at asc;
