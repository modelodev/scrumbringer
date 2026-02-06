-- name: milestones_delete
with deleted as (
  delete from milestones m
  where m.id = $1
    and m.state = 'ready'
    and not exists (
      select 1 from cards c where c.milestone_id = m.id
    )
    and not exists (
      select 1 from tasks t where t.milestone_id = m.id
    )
  returning id
)
select id from deleted;
