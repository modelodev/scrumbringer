-- name: activate_milestone
with project_lock as (
  select id
  from projects
  where id = $2
  for update
), has_active as (
  select exists(
    select 1
    from milestones
    where project_id = $2
      and state = 'active'
      and id != $1
  ) as blocked
), updated as (
  update milestones m
  set
    state = 'active',
    activated_at = now()
  where m.id = $1
    and m.project_id = $2
    and m.state = 'ready'
    and exists(select 1 from project_lock)
    and (select blocked from has_active) = false
  returning
    m.id,
    m.project_id,
    m.name,
    coalesce(m.description, '') as description,
    m.state,
    m.position,
    m.created_by,
    to_char(m.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    to_char(m.activated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as activated_at,
    coalesce(to_char(m.completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at
)
select
  u.*,
  coalesce(c.cards_released, 0) as cards_released,
  coalesce(t.tasks_released, 0) as tasks_released
from updated u
left join lateral (
  select count(*) as cards_released
  from cards c
  where c.project_id = u.project_id
    and c.milestone_id = u.id
) c on true
left join lateral (
  select count(*) as tasks_released
  from tasks t
  left join cards c on c.id = t.card_id
  where t.project_id = u.project_id
    and coalesce(t.milestone_id, c.milestone_id) = u.id
) t on true;
