import gleam/option as opt

import domain/automation
import domain/workflow.{
  type Rule, type TaskTemplate, type Workflow, Rule, TaskTemplate, Workflow,
}
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/features/automations/focus_target as automation_focus
import scrumbringer_client/features/pool/admin_route

fn engine(id: Int) -> Workflow {
  Workflow(
    id: id,
    org_id: 1,
    project_id: opt.Some(7),
    name: "Release automation",
    description: opt.None,
    active: True,
    rule_count: 1,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn rule(id: Int) -> Rule {
  Rule(
    id: id,
    workflow_id: 3,
    name: "Complete bug workflow",
    goal: opt.None,
    trigger: automation.TaskCompleted(opt.None),
    action: opt.Some(automation.CreateTask(11)),
    status: automation.Active,
    created_at: "2026-01-01T00:00:00Z",
    template: opt.None,
  )
}

fn template(id: Int) -> TaskTemplate {
  TaskTemplate(
    id: id,
    org_id: 1,
    project_id: opt.Some(7),
    name: "Regression checklist",
    description: opt.None,
    type_id: 2,
    type_name: "Bug",
    priority: 3,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 1,
    created_tasks_count: 4,
    last_execution_at: opt.None,
  )
}

pub fn automation_engine_panel_focus_targets_return_to_opening_trigger_test() {
  let assert opt.Some(expected_create) =
    admin_route.engine_dialog_focus_target_for_test(opt.Some(
      admin_workflows.EngineDialogCreate,
    ))
  let assert True = expected_create == automation_focus.create_engine_trigger_id
  let assert opt.Some(expected_edit) =
    admin_route.engine_dialog_focus_target_for_test(
      opt.Some(admin_workflows.EngineDialogEdit(engine(3))),
    )
  let assert True = expected_edit == automation_focus.engine_edit_trigger_id(3)
  let assert opt.Some(expected_delete) =
    admin_route.engine_dialog_focus_target_for_test(
      opt.Some(admin_workflows.EngineDialogDelete(engine(3))),
    )
  let assert True =
    expected_delete == automation_focus.engine_delete_trigger_id(3)
  let assert opt.None =
    admin_route.engine_dialog_focus_target_for_test(opt.None)
}

pub fn automation_rule_panel_focus_targets_return_to_opening_trigger_test() {
  let assert opt.Some(expected_create) =
    admin_route.rule_dialog_focus_target_for_test(opt.Some(
      admin_rules.RuleDialogCreate,
    ))
  let assert True = expected_create == automation_focus.create_rule_trigger_id
  let assert opt.Some(expected_edit) =
    admin_route.rule_dialog_focus_target_for_test(
      opt.Some(admin_rules.RuleDialogEdit(rule(9))),
    )
  let assert True = expected_edit == automation_focus.rule_edit_trigger_id(9)
  let assert opt.Some(expected_delete) =
    admin_route.rule_dialog_focus_target_for_test(
      opt.Some(admin_rules.RuleDialogDelete(rule(9))),
    )
  let assert True =
    expected_delete == automation_focus.rule_delete_trigger_id(9)
  let assert opt.None = admin_route.rule_dialog_focus_target_for_test(opt.None)
}

pub fn automation_template_panel_focus_targets_return_to_opening_trigger_test() {
  let assert opt.Some(expected_create) =
    admin_route.task_template_dialog_focus_target_for_test(opt.Some(
      admin_task_templates.TaskTemplateDialogCreate,
    ))
  let assert True =
    expected_create == automation_focus.create_template_trigger_id
  let assert opt.Some(expected_edit) =
    admin_route.task_template_dialog_focus_target_for_test(
      opt.Some(admin_task_templates.TaskTemplateDialogEdit(template(7))),
    )
  let assert True =
    expected_edit == automation_focus.template_edit_trigger_id(7)
  let assert opt.Some(expected_delete) =
    admin_route.task_template_dialog_focus_target_for_test(
      opt.Some(admin_task_templates.TaskTemplateDialogDelete(template(7))),
    )
  let assert True =
    expected_delete == automation_focus.template_delete_trigger_id(7)
  let assert opt.None =
    admin_route.task_template_dialog_focus_target_for_test(opt.None)
}
