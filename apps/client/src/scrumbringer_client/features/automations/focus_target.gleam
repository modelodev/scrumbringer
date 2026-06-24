//// Stable focus targets for the automation console.

import gleam/int

pub const create_engine_trigger_id = "automation-create-engine-trigger"

pub const create_rule_trigger_id = "automation-create-rule-trigger"

pub const create_template_trigger_id = "automation-create-template-trigger"

pub fn engine_edit_trigger_id(engine_id: Int) -> String {
  "automation-engine-edit-trigger-" <> int.to_string(engine_id)
}

pub fn engine_delete_trigger_id(engine_id: Int) -> String {
  "automation-engine-delete-trigger-" <> int.to_string(engine_id)
}

pub fn rule_edit_trigger_id(rule_id: Int) -> String {
  "automation-rule-edit-trigger-" <> int.to_string(rule_id)
}

pub fn rule_delete_trigger_id(rule_id: Int) -> String {
  "automation-rule-delete-trigger-" <> int.to_string(rule_id)
}

pub fn template_edit_trigger_id(template_id: Int) -> String {
  "automation-template-edit-trigger-" <> int.to_string(template_id)
}

pub fn template_delete_trigger_id(template_id: Int) -> String {
  "automation-template-delete-trigger-" <> int.to_string(template_id)
}
