-- migrate:up

WITH ranked_rule_templates AS (
  SELECT
    rule_id,
    template_id,
    row_number() OVER (
      PARTITION BY rule_id
      ORDER BY execution_order ASC, template_id ASC
    ) AS selected_rank
  FROM public.rule_templates
)
DELETE FROM public.rule_templates rt
USING ranked_rule_templates ranked
WHERE rt.rule_id = ranked.rule_id
  AND rt.template_id = ranked.template_id
  AND ranked.selected_rank > 1;

CREATE UNIQUE INDEX IF NOT EXISTS rule_templates_single_template_per_rule_key
  ON public.rule_templates(rule_id);

-- migrate:down

DROP INDEX IF EXISTS public.rule_templates_single_template_per_rule_key;
