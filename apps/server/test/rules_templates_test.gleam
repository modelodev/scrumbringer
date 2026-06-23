import scrumbringer_server/use_case/rules_templates

pub fn substitute_uses_current_automation_variables_test() {
  let rendered =
    rules_templates.substitute(
      "{{origin}} {{trigger}} {{project}} {{user}}",
      rules_templates.EventContext(
        origin: "[Task #42](/tasks/42)",
        trigger: "completed",
        project_name: "Core",
        user_name: "admin@example.com",
        task_title: "Fix bug",
        task_type: "Bug",
        card_title: "",
        card_level: "",
      ),
    )

  let assert "[Task #42](/tasks/42) completed Core admin@example.com" = rendered
}

pub fn substitute_leaves_legacy_variables_unresolved_test() {
  let rendered =
    rules_templates.substitute(
      "{{father}} {{from_state}} {{to_state}}",
      rules_templates.EventContext(
        origin: "[Task #42](/tasks/42)",
        trigger: "completed",
        project_name: "Core",
        user_name: "admin@example.com",
        task_title: "Fix bug",
        task_type: "Bug",
        card_title: "",
        card_level: "",
      ),
    )

  let assert "{{father}} {{from_state}} {{to_state}}" = rendered
}

pub fn substitute_uses_trigger_specific_variables_test() {
  let rendered =
    rules_templates.substitute(
      "{{task_title}} {{task_type}} {{card_title}} {{card_level}}",
      rules_templates.EventContext(
        origin: "[Card #7](/cards/7)",
        trigger: "en_curso",
        project_name: "Core",
        user_name: "admin@example.com",
        task_title: "Fix bug",
        task_type: "Bug",
        card_title: "Checkout",
        card_level: "2",
      ),
    )

  let assert "Fix bug Bug Checkout 2" = rendered
}
