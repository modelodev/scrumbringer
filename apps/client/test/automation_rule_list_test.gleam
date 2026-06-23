import gleam/int
import gleam/option as opt
import gleam/set
import gleam/string
import lustre/element

import domain/remote.{Loaded, NotAsked}
import domain/task_status
import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow, Rule,
  RuleTemplate, TaskRule, TaskTemplate, Workflow,
}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/features/automations/rule_list
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn workflow(id: Int, name: String) -> Workflow {
  Workflow(
    id: id,
    org_id: 1,
    project_id: opt.Some(7),
    name: name,
    description: opt.None,
    active: True,
    rule_count: 1,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn task_type() -> TaskType {
  TaskType(
    id: 5,
    name: "Bug",
    icon: "bug-ant",
    capability_id: opt.None,
    tasks_count: 0,
  )
}

fn rule_template() -> RuleTemplate {
  RuleTemplate(
    id: 11,
    org_id: 1,
    project_id: opt.Some(7),
    name: "Bug triage",
    description: opt.None,
    type_id: 5,
    type_name: "Bug",
    priority: 2,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    execution_order: 1,
  )
}

fn task_template() -> TaskTemplate {
  TaskTemplate(
    id: 12,
    org_id: 1,
    project_id: opt.Some(7),
    name: "Follow-up task",
    description: opt.None,
    type_id: 5,
    type_name: "Bug",
    priority: 3,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 0,
  )
}

fn rule() -> Rule {
  Rule(
    id: 9,
    workflow_id: 3,
    name: "Complete bug workflow",
    goal: opt.Some("Create a follow-up when work completes"),
    target: TaskRule(task_status.Done, opt.Some(5)),
    active: True,
    created_at: "2026-01-01T00:00:00Z",
    templates: [rule_template()],
  )
}

fn rules_state() -> admin_rules.Model {
  admin_rules.Model(
    ..admin_rules.default_model(),
    rules_workflow_id: opt.Some(3),
    rules: Loaded([rule()]),
    rules_expanded: set.from_list([9]),
    rules_metrics: Loaded(
      api_rule_metrics.WorkflowMetrics(
        workflow_id: 3,
        workflow_name: "Release automation",
        rules: [
          api_rule_metrics.RuleMetricsSummary(
            rule_id: 9,
            rule_name: "Complete bug workflow",
            evaluated_count: 6,
            applied_count: 4,
            suppressed_count: 2,
          ),
        ],
      ),
    ),
  )
}

fn config() -> rule_list.Config(String) {
  rule_list.Config(
    locale: locale.En,
    theme: theme.Default,
    workflow_id: 3,
    workflow_name: "Release automation",
    rules: rules_state(),
    workflows_org: NotAsked,
    workflows_project: Loaded([workflow(3, "Release automation")]),
    task_types: Loaded([task_type()]),
    task_templates_org: Loaded([]),
    task_templates_project: Loaded([task_template()]),
    on_back_clicked: "back",
    on_create_clicked: "create",
    on_rule_expanded: fn(id) { "expand-" <> int.to_string(id) },
    on_edit_clicked: fn(rule) { "edit-" <> rule.name },
    on_delete_clicked: fn(rule) { "delete-" <> rule.name },
    on_attach_modal_opened: fn(id) { "attach-open-" <> int.to_string(id) },
    on_attach_modal_closed: "attach-close",
    on_template_detached: fn(rule_id, template_id) {
      "detach-" <> int.to_string(rule_id) <> "-" <> int.to_string(template_id)
    },
    on_template_selected: fn(template_id) {
      "select-" <> int.to_string(template_id)
    },
    on_attach_submitted: "attach-submit",
    on_rule_name_changed: fn(value) { "name-" <> value },
    on_rule_goal_changed: fn(value) { "goal-" <> value },
    on_rule_subject_changed: fn(value) { "subject-" <> value },
    on_rule_task_type_changed: fn(value) { "task-type-" <> value },
    on_rule_event_changed: fn(value) { "event-" <> value },
    on_rule_template_changed: fn(value) { "template-" <> value },
    on_rule_active_changed: fn(value) {
      "active-"
      <> case value {
        True -> "true"
        False -> "false"
      }
    },
    on_rule_submitted: "rule-submit",
    on_rule_delete_confirmed: "rule-delete-confirmed",
    on_rule_panel_closed: "closed",
    on_noop: "noop",
  )
}

pub fn automation_rule_list_renders_rules_from_config_without_root_model_test() {
  let html =
    rule_list.view(config())
    |> element.to_document_string

  assert_contains(html, "Rules - Release automation")
  assert_contains(html, "Back to Automations")
  assert_contains(html, "Complete bug workflow")
  assert_contains(html, "Automatizacion")
  assert_contains(html, "When a Bug task is completed")
  assert_contains(html, "-&gt; Create Bug triage in the Pool")
  assert_not_contains(html, "Resource Type")
  assert_not_contains(html, "Target State")
  assert_contains(html, "Bug triage")
  assert_contains(html, "4")
  assert_contains(html, "2")
  assert_contains(html, "btn-view-action")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "btn-icon-text")
  assert_not_contains(html, "btn btn-sm btn-primary")
}

pub fn automation_rule_list_renders_empty_state_from_config_without_root_model_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        rules: admin_rules.Model(..rules_state(), rules: Loaded([])),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "No rules yet")
}

pub fn automation_rule_list_renders_rule_builder_from_config_without_root_model_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Follow-up when bug closes",
          rule_form_subject: "task",
          rule_form_task_type_id: "5",
          rule_form_event: "task_completed",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "automation-rule-panel")
  assert_contains(html, "data-testid=\"automation-rule-builder\"")
  assert_contains(html, "New rule")
  assert_contains(html, "When")
  assert_contains(html, "Any task type")
  assert_contains(html, "Bug")
  assert_contains(html, "Preview")
  assert_contains(html, "When a Bug task is completed")
  assert_contains(html, "Create task from")
  assert_contains(html, "data-testid=\"automation-template-picker\"")
  assert_contains(html, "Follow-up task")
  assert_contains(html, "It will create &quot;Follow-up task&quot;")
  assert_not_contains(html, "rule-crud-dialog")
  assert_not_contains(html, "Resource Type")
  assert_not_contains(html, "Target State")
}

pub fn automation_rule_list_attach_modal_footer_uses_semantic_buttons_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        rules: admin_rules.Model(
          ..rules_state(),
          attach_template_modal: opt.Some(9),
          attach_template_loading: True,
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Select Template")
  assert_contains(html, "btn-secondary")
  assert_contains(html, "btn-primary")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, "btn-loading")
  assert_contains(html, "Selecting")
  assert_contains(html, "disabled")
}
