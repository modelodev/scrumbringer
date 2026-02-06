-- name: recompute_milestone_completion
with stats as (
  select
    m.id,
    m.project_id,
    coalesce((
      select count(*)
      from cards c
      where c.project_id = m.project_id
        and c.milestone_id = m.id
    ), 0) as cards_total,
    coalesce((
      select count(*)
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
      ) x
      where x.task_count > 0
        and x.task_count = x.completed_count
    ), 0) as cards_completed,
    coalesce((
      select count(*)
      from tasks t
      where t.project_id = m.project_id
        and t.card_id is null
        and t.milestone_id = m.id
    ), 0) as tasks_total,
    coalesce((
      select count(*)
      from tasks t
      where t.project_id = m.project_id
        and t.card_id is null
        and t.milestone_id = m.id
        and t.status = 'completed'
    ), 0) as tasks_completed
  from milestones m
  where m.id = $1
), updated as (
  update milestones m
  set
    state = case
      when (s.cards_total = 0 and s.tasks_total = 0) then m.state
      when (s.cards_completed = s.cards_total and s.tasks_completed = s.tasks_total) then 'completed'
      when m.state = 'completed' then 'active'
      else m.state
    end,
    completed_at = case
      when (s.cards_total = 0 and s.tasks_total = 0) then m.completed_at
      when (s.cards_completed = s.cards_total and s.tasks_completed = s.tasks_total)
        then coalesce(m.completed_at, now())
      when m.state = 'completed' then null
      else m.completed_at
    end
  from stats s
  where m.id = s.id
    and m.state in ('active', 'completed')
  returning
    m.id,
    m.project_id,
    m.name,
    coalesce(m.description, '') as description,
    m.state,
    m.position,
    m.created_by,
    to_char(m.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    coalesce(to_char(m.activated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as activated_at,
    coalesce(to_char(m.completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at
)
select *
from updated;
