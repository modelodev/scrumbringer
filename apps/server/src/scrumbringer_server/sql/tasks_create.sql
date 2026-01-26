-- name: create_task
-- Create a new task in a project, ensuring the task type belongs to the project
-- and optionally associating with a card (if card_id is provided and belongs to same project).
with type_ok as (
  select id
  from task_types
  where id = $1
    and project_id = $2
), card_ok as (
  -- If card_id <= 0, allow creation.
  -- If card_id is provided, require it to belong to the same project.
  select case
    when $7 <= 0 then null
    else (select id from cards where id = $7 and project_id = $2)
  end as id
), inserted as (
  insert into tasks (project_id, type_id, title, description, priority, created_by, card_id)
  select
    $2,
    type_ok.id,
    $3,
    nullif($4, ''),
    $5,
    $6,
    card_ok.id
  from type_ok, card_ok
  where type_ok.id is not null
    -- Block if card_id is provided but card_ok.id is null (invalid card)
    and ($7 <= 0 or card_ok.id is not null)
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
    coalesce(to_char(completed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    version,
    coalesce(card_id, 0) as card_id
)
select
  inserted.*,
  tt.name as type_name,
  tt.icon as type_icon,
  (false) as is_ongoing,
  0 as ongoing_by_user_id,
  coalesce(c.title, '') as card_title,
  coalesce(c.color, '') as card_color
from inserted
join task_types tt on tt.id = inserted.type_id
left join cards c on c.id = inserted.card_id;
