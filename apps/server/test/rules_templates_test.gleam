import scrumbringer_server/use_case/rules_templates

pub fn substitute_uses_current_automation_variables_test() {
  let rendered =
    rules_templates.substitute(
      "{{origin}} {{trigger}} {{project}} {{user}}",
      rules_templates.EventContext(
        origin: "[Task #42](/tasks/42)",
        trigger: "closed",
        project_name: "Core",
        user_name: "admin@example.com",
        task_title: "Fix bug",
        task_type: "Bug",
        card_title: "",
        card_level: "",
      ),
    )

  let assert "[Task #42](/tasks/42) closed Core admin@example.com" = rendered
}

pub fn substitute_leaves_unknown_variables_unresolved_test() {
  let rendered =
    rules_templates.substitute(
      "{{unsupported}} {{previous_status}} {{next_status}}",
      rules_templates.EventContext(
        origin: "[Task #42](/tasks/42)",
        trigger: "closed",
        project_name: "Core",
        user_name: "admin@example.com",
        task_title: "Fix bug",
        task_type: "Bug",
        card_title: "",
        card_level: "",
      ),
    )

  let assert "{{unsupported}} {{previous_status}} {{next_status}}" = rendered
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
