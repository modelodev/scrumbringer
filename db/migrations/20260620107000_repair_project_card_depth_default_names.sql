-- migrate:up

UPDATE public.project_card_depth_names
SET singular_name = 'Initiative',
    plural_name = 'Initiatives'
WHERE depth = 1
  AND (
    (singular_name = 'Card' AND plural_name = 'Cards')
    OR (
      singular_name = 'Hito'
      AND plural_name = 'Hitos'
      AND EXISTS (
        SELECT 1
        FROM public.project_card_depth_names sibling
        WHERE sibling.project_id = project_card_depth_names.project_id
          AND sibling.depth = 2
          AND sibling.singular_name = 'Card'
          AND sibling.plural_name = 'Cards'
      )
    )
  );

UPDATE public.project_card_depth_names
SET singular_name = 'Feature',
    plural_name = 'Features'
WHERE depth = 2
  AND (
    (singular_name = 'Card' AND plural_name = 'Cards')
    OR (singular_name = 'Initiative' AND plural_name = 'Initiatives')
  );

INSERT INTO public.project_card_depth_names
  (project_id, depth, singular_name, plural_name)
SELECT
  project.id,
  names.depth,
  names.singular_name,
  names.plural_name
FROM public.projects project
CROSS JOIN (
  VALUES
    (1, 'Initiative', 'Initiatives'),
    (2, 'Feature', 'Features'),
    (3, 'Task group', 'Task groups')
) AS names(depth, singular_name, plural_name)
ON CONFLICT (project_id, depth) DO NOTHING;

-- migrate:down

DO $$
BEGIN
  RAISE EXCEPTION 'repair_project_card_depth_default_names_is_irreversible';
END $$;
