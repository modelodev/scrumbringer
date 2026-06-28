select exists(
  select 1
  from task_types
  where id = $1
    and project_id = $2
) as ok;
