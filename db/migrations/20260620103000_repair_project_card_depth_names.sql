-- migrate:up

INSERT INTO public.project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT
  p.id,
  names.depth,
  names.singular_name,
  names.plural_name
FROM public.projects p
CROSS JOIN (
  VALUES
    (1, 'Initiative', 'Initiatives'),
    (2, 'Feature', 'Features'),
    (3, 'Task group', 'Task groups')
) AS names(depth, singular_name, plural_name)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.project_card_depth_names existing
  WHERE existing.project_id = p.id
    AND existing.depth = names.depth
)
ON CONFLICT (project_id, depth) DO NOTHING;

-- migrate:down

DO $$
BEGIN
  RAISE EXCEPTION 'repair_project_card_depth_names_is_irreversible';
END $$;
