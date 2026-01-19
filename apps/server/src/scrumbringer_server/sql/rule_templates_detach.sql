-- name: detach_rule_template
DELETE FROM rule_templates
WHERE rule_id = $1
  AND template_id = $2
RETURNING rule_id;
