import scrumbringer_server/use_case/rules_templates

pub fn substitute_uses_current_automation_variables_test() {
  let rendered =
    rules_templates.substitute(
      "{{origin}} {{trigger}} {{project}} {{user}}",
      "[Task #42](/tasks/42)",
      "completed",
      "Core",
      "admin@example.com",
    )

  let assert "[Task #42](/tasks/42) completed Core admin@example.com" = rendered
}

pub fn substitute_leaves_legacy_variables_unresolved_test() {
  let rendered =
    rules_templates.substitute(
      "{{father}} {{from_state}} {{to_state}}",
      "[Task #42](/tasks/42)",
      "completed",
      "Core",
      "admin@example.com",
    )

  let assert "{{father}} {{from_state}} {{to_state}}" = rendered
}
