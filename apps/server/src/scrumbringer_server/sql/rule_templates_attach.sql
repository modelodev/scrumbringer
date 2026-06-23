-- name: attach_rule_template
-- A rule has exactly one task template in the automation model.
-- Re-attaching selects/replaces the rule template and removes any previous one.
WITH removed AS (
  DELETE FROM rule_templates
  WHERE rule_id = $1
    AND template_id <> $2
  RETURNING rule_id
)
INSERT INTO rule_templates (rule_id, template_id, execution_order)
VALUES ($1, $2, $3)
ON CONFLICT (rule_id, template_id)
DO UPDATE SET execution_order = EXCLUDED.execution_order
RETURNING rule_id;
