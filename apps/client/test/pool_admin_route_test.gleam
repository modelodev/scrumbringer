import gleam/option as opt
import lustre/effect

import domain/remote.{Loaded}
import domain/workflow.{type TaskTemplate, TaskTemplate}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/features/pool/admin_route
import scrumbringer_client/features/pool/msg as pool_messages

fn template(id: Int, name: String) -> TaskTemplate {
  TaskTemplate(
    id: id,
    org_id: 1,
    project_id: opt.Some(7),
    name: name,
    description: opt.None,
    type_id: 2,
    type_name: "Bug",
    priority: 3,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 0,
    created_tasks_count: 0,
    last_execution_at: opt.None,
  )
}

fn model_with_rule_builder(
  template_dialog_mode: opt.Option(admin_task_templates.TaskTemplateDialogMode),
  selected_template_id: String,
) -> client_state.Model {
  client_state.update_admin(client_state.default_model(), fn(admin) {
    admin_state.AdminModel(
      ..admin,
      rules: admin_rules.Model(
        ..admin.rules,
        rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
        rule_form_template_id: selected_template_id,
        rule_form_template_search: "Follow",
        rule_form_error: opt.Some("Choose one template"),
      ),
      task_templates: admin_task_templates.Model(
        ..admin.task_templates,
        task_templates_project: Loaded([]),
        task_templates_dialog_mode: template_dialog_mode,
      ),
    )
  })
}

pub fn created_template_from_rule_builder_is_selected_test() {
  let created = template(42, "Follow-up")
  let model =
    model_with_rule_builder(
      opt.Some(admin_task_templates.TaskTemplateDialogCreate),
      "",
    )

  let assert opt.Some(#(next, fx)) =
    admin_route.try_update(
      model,
      pool_messages.TaskTemplateSaved(Ok(created)),
      fn(_) { opt.None },
    )

  let assert "42" = next.admin.rules.rule_form_template_id
  let assert "" = next.admin.rules.rule_form_template_search
  let assert opt.None = next.admin.rules.rule_form_error
  let assert True =
    next.admin.task_templates.task_templates_project == Loaded([created])
  let assert True = fx != effect.none()
}

pub fn edited_template_does_not_replace_rule_builder_selection_test() {
  let updated = template(42, "Follow-up")
  let original = template(12, "Original")
  let model =
    model_with_rule_builder(
      opt.Some(admin_task_templates.TaskTemplateDialogEdit(original)),
      "12",
    )

  let assert opt.Some(#(next, _fx)) =
    admin_route.try_update(
      model,
      pool_messages.TaskTemplateSaved(Ok(updated)),
      fn(_) { opt.None },
    )

  let assert "12" = next.admin.rules.rule_form_template_id
}
