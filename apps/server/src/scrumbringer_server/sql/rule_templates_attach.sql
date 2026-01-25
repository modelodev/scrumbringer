-- name: attach_rule_template
-- Idempotent: if already exists, update execution_order and still return a row.
-- This prevents false "not found" errors when re-attaching.
INSERT INTO rule_templates (rule_id, template_id, execution_order)
VALUES ($1, $2, $3)
ON CONFLICT (rule_id, template_id)
DO UPDATE SET execution_order = EXCLUDED.execution_order
RETURNING rule_id;
