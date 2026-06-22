-- migrate:up

INSERT INTO public.task_types (project_id, name, icon)
SELECT
  project.id,
  task_type.name,
  task_type.icon
FROM public.projects project
CROSS JOIN (
  VALUES
    ('General', 'check-square')
) AS task_type(name, icon)
ON CONFLICT (name, project_id) DO NOTHING;

-- migrate:down

DELETE FROM public.task_types
WHERE name = 'General'
  AND NOT EXISTS (
    SELECT 1
    FROM public.tasks task
    WHERE task.type_id = task_types.id
  );
