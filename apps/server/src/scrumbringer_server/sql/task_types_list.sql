-- name: list_task_types_for_project
-- Story 4.9 AC15: Include tasks_count for each task type
select
  tt.id,
  tt.project_id,
  tt.name,
  tt.icon,
  coalesce(tt.capability_id, 0) as capability_id,
  coalesce(task_counts.count, 0) as tasks_count
from task_types tt
left join (
  select type_id, count(*) as count
  from tasks
  group by type_id
) task_counts on task_counts.type_id = tt.id
where tt.project_id = $1
order by tt.name asc;
