-- name: create_task
-- Create a new task in a project, ensuring the task type belongs to the project
-- and optionally associating with a card (if card_id is provided and belongs to same project).
with type_ok as (
  select id
  from task_types
  where id = $1
    and project_id = $2
), card_ok as (
  select c.id, c.execution_state
  from (select 1) seed
  left join cards c
    on c.id = $7 and c.project_id = $2
    and c.execution_state <> 'closed'
    and not exists (
      select 1
      from cards child
      where child.parent_card_id = c.id
    )
  where $7 <= 0 or c.id is not null
), inserted as (
  insert into tasks (
    project_id,
    type_id,
    title,
    description,
    priority,
    created_by,
    card_id,
    created_from_rule_id,
    execution_state,
    last_entered_pool_at
  )
  select
    $2,
    type_ok.id,
    $3,
    nullif($4, ''),
    $5,
    $6,
    case when $7 <= 0 then null else card_ok.id end,
    case when $9 <= 0 then null else $9 end,
    'available',
    case
      when $7 <= 0 then now()
      when card_ok.execution_state = 'active' then now()
      else null
    end
  from type_ok, card_ok
  where type_ok.id is not null
    and ($7 <= 0 or card_ok.id is not null)
    and ($8 <= 0 or $8 > 0)
  returning
    id,
    project_id,
    type_id,
    title,
    coalesce(description, '') as description,
    priority,
    execution_state as status,
    created_by,
    coalesce(claimed_by, 0) as claimed_by,
    coalesce(to_char(claimed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as claimed_at,
    coalesce(to_char(closed_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as completed_at,
    to_char(created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    coalesce(to_char(due_date, 'YYYY-MM-DD'), '') as due_date,
    version,
    coalesce(card_id, 0) as card_id,
    0 as parent_card_id,
    pool_lifetime_s,
    coalesce(to_char(last_entered_pool_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '') as last_entered_pool_at,
    coalesce(created_from_rule_id, 0) as created_from_rule_id,
    0 as automation_execution_id,
    0 as automation_template_id,
    0 as automation_template_version
)
select
  inserted.*,
  tt.name as type_name,
  tt.icon as type_icon,
  false as is_ongoing,
  0 as ongoing_by_user_id,
  coalesce(c.title, '') as card_title,
  coalesce(c.color, '') as card_color,
  '[]'::text as dependencies,
  0 as blocked_count
from inserted
join task_types tt on tt.id = inserted.type_id
left join cards c on c.id = inserted.card_id;
