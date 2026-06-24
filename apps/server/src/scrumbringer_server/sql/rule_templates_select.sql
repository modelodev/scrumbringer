-- name: select_rule_template
-- A rule has exactly one task template in the automation model.
INSERT INTO rule_templates (rule_id, template_id, execution_order)
VALUES ($1, $2, $3)
ON CONFLICT (rule_id)
DO UPDATE SET
  template_id = EXCLUDED.template_id,
  execution_order = EXCLUDED.execution_order
RETURNING rule_id;
