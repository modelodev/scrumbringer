-- name: attach_rule_template
INSERT INTO rule_templates (rule_id, template_id, execution_order)
VALUES ($1, $2, $3)
ON CONFLICT (rule_id, template_id)
DO NOTHING
RETURNING rule_id;
