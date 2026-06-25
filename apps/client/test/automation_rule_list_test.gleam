import gleam/int
import gleam/option as opt
import gleam/set
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html.{div, text}

import domain/automation
import domain/remote.{Loaded, NotAsked}
import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{
  type Rule, type RuleTemplate, type TaskTemplate, type Workflow, Rule,
  RuleTemplate, TaskTemplate, Workflow,
}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/features/automations/focus_target as automation_focus
import scrumbringer_client/features/automations/rule_list
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn engine(id: Int, name: String) -> Workflow {
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
    description: opt.Some("Manual QA review"),
    type_id: 5,
    type_name: "Bug",
    priority: 3,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 0,
    created_tasks_count: 0,
    last_execution_at: opt.None,
  )
}

fn docs_template() -> TaskTemplate {
  TaskTemplate(
    id: 13,
    org_id: 1,
    project_id: opt.Some(7),
    name: "Docs sweep",
    description: opt.None,
    type_id: 5,
    type_name: "Bug",
    priority: 1,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 0,
    created_tasks_count: 0,
    last_execution_at: opt.None,
  )
}

fn card_variable_template() -> TaskTemplate {
  TaskTemplate(
    id: 14,
    org_id: 1,
    project_id: opt.Some(7),
    name: "Card follow-up",
    description: opt.Some("Review {{card_title}}"),
    type_id: 5,
    type_name: "Bug",
    priority: 3,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 0,
    created_tasks_count: 0,
    last_execution_at: opt.None,
  )
}

fn rule() -> Rule {
  Rule(
    id: 9,
    workflow_id: 3,
    name: "Close bug workflow",
    goal: opt.Some("Create a follow-up when work closes"),
    trigger: automation.TaskClosed(opt.Some(5)),
    action: opt.Some(automation.CreateTask(11)),
    status: automation.Active,
    created_at: "2026-01-01T00:00:00Z",
    template: opt.Some(rule_template()),
  )
}

fn rules_state() -> admin_rules.Model {
  admin_rules.Model(
    ..admin_rules.default_model(),
    rules_engine_id: opt.Some(3),
    rules: Loaded([rule()]),
    rules_expanded: set.from_list([9]),
    rules_metrics: Loaded(
      api_rule_metrics.WorkflowMetrics(
        workflow_id: 3,
        workflow_name: "Release automation",
        rules: [
          api_rule_metrics.RuleMetricsSummary(
            rule_id: 9,
            rule_name: "Close bug workflow",
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
    engine_id: 3,
    selected_rule_id: opt.None,
    engine_name: "Release automation",
    rules: rules_state(),
    engines_org: NotAsked,
    engines_project: Loaded([engine(3, "Release automation")]),
    task_types: Loaded([task_type()]),
    task_templates_org: Loaded([]),
    task_templates_project: Loaded([task_template()]),
    template_panel_open: False,
    template_panel: element.none(),
    depth_names: [
      scope_view.DepthName(1, "Initiative", "Initiatives"),
      scope_view.DepthName(2, "Feature", "Features"),
      scope_view.DepthName(3, "Story", "Stories"),
    ],
    on_back_clicked: "back",
    on_create_clicked: "create",
    on_rule_expanded: fn(id) { "expand-" <> int.to_string(id) },
    on_edit_clicked: fn(rule) { "edit-" <> rule.name },
    on_delete_clicked: fn(rule) { "delete-" <> rule.name },
    on_rule_name_changed: fn(value) { "name-" <> value },
    on_rule_goal_changed: fn(value) { "goal-" <> value },
    on_rule_subject_changed: fn(value) { "subject-" <> value },
    on_rule_task_type_changed: fn(value) { "task-type-" <> value },
    on_rule_event_changed: fn(value) { "event-" <> value },
    on_rule_card_scope_changed: fn(value) { "card-scope-" <> value },
    on_rule_template_search_changed: fn(value) { "template-search-" <> value },
    on_rule_template_changed: fn(value) { "template-" <> value },
    on_create_template_clicked: "create-template",
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

pub fn automation_rule_list_renders_card_scope_picker_and_preview_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Delivery review",
          rule_form_subject: "card",
          rule_form_event: "card_closed",
          rule_form_card_scope: "2",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Card automation scope")
  assert_contains(html, "inert")
  assert_contains(html, "aria-hidden=\"true\"")
  assert_contains(html, "role=\"dialog\"")
  assert_contains(html, "aria-modal=\"true\"")
  assert_contains(html, "aria-labelledby=\"automation-rule-panel-title\"")
  assert_contains(html, "id=\"automation-rule-panel-title\"")
  assert_contains(html, "aria-label=\"Name\"")
  assert_contains(html, "autofocus")
  assert_not_contains(
    html,
    "id=\"automation-rule-panel-title\" tabindex=\"-1\"",
  )
  assert_contains(html, "aria-keyshortcuts=\"Escape\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_contains(html, "aria-label=\"Goal\"")
  assert_contains(html, "aria-label=\"Rule subject\"")
  assert_contains(html, "aria-label=\"Event\"")
  assert_contains(html, "aria-label=\"Rule task template\"")
  assert_contains(html, ">Any card<")
  assert_contains(html, ">Cards at level: Initiative<")
  assert_contains(html, ">Cards at level: Feature<")
  assert_contains(html, ">Cards at level: Story<")
  assert_contains(html, "value=\"2\"")
  assert_contains(html, "When a Feature is closed")
  assert_not_contains(html, "type=\"number\"")
  assert_not_contains(html, "subtree")
}

pub fn automation_rule_builder_rejects_missing_card_depth_scope_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Stale card scope",
          rule_form_subject: "card",
          rule_form_event: "card_activated",
          rule_form_card_scope: "9",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Card level 9 is no longer available.")
  assert_contains(html, "Choose an existing card level or Any card.")
  assert_contains(html, "role=\"alert\"")
  assert_contains(html, "disabled")
  assert_not_contains(html, "value=\"9\" selected")
}

pub fn automation_rule_delete_panel_focuses_title_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogDelete(rule())),
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "automation-rule-panel-danger")
  assert_contains(html, "inert")
  assert_contains(html, "aria-hidden=\"true\"")
  assert_contains(html, "aria-labelledby=\"automation-rule-panel-title\"")
  assert_contains(html, "id=\"automation-rule-panel-title\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_contains(html, "autofocus")
  assert_contains(html, "Delete rule")
}

pub fn automation_rule_list_renders_rules_from_config_without_root_model_test() {
  let html =
    rule_list.view(config())
    |> element.to_document_string

  assert_contains(html, "Rules - Release automation")
  assert_contains(html, "Back to Automations")
  assert_contains(html, "automation-rules-heading")
  assert_contains(html, automation_focus.create_rule_trigger_id)
  assert_contains(html, "automation-rule-list")
  assert_contains(html, "Close bug workflow")
  assert_contains(html, "When a Bug task is closed")
  assert_contains(html, "-&gt; Create Bug triage in the Pool")
  assert_contains(html, "Engine:")
  assert_contains(html, "Release automation")
  assert_contains(html, "Template:")
  assert_contains(html, "Created:")
  assert_contains(html, "Ignored:")
  assert_not_contains(html, "data-table")
  assert_not_contains(html, "<table")
  assert_not_contains(html, "Automatizacion")
  assert_not_contains(html, "Resource Type")
  assert_not_contains(html, "Target State")
  assert_not_contains(html, "Suppressed")
  assert_not_contains(html, "admin-section-header")
  assert_contains(html, "Bug triage")
  assert_contains(html, "4")
  assert_contains(html, "2")
  assert_contains(html, "btn-view-action")
  assert_contains(html, "btn-entity-action")
  assert_contains(html, automation_focus.rule_edit_trigger_id(9))
  assert_contains(html, automation_focus.rule_delete_trigger_id(9))
  assert_not_contains(html, "inert")
  assert_not_contains(html, "btn btn-sm btn-primary")
}

pub fn automation_rule_list_localizes_rule_meta_labels_test() {
  let html =
    rule_list.view(rule_list.Config(..config(), locale: locale.Es))
    |> element.to_document_string

  assert_contains(html, "Motor:")
  assert_contains(html, "Plantilla:")
  assert_contains(html, "Creadas:")
  assert_contains(html, "Ignoradas:")
  assert_not_contains(html, "Engine:")
  assert_not_contains(html, "Template:")
  assert_not_contains(html, "Created:")
  assert_not_contains(html, "Ignored:")
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

pub fn automation_rule_list_marks_selected_rule_test() {
  let html =
    rule_list.view(rule_list.Config(..config(), selected_rule_id: opt.Some(9)))
    |> element.to_document_string

  assert_contains(html, "data-testid=\"automation-rule-row\"")
  assert_contains(html, "role=\"button\"")
  assert_contains(html, "tabindex=\"0\"")
  assert_contains(html, "data-selected=\"true\"")
  assert_contains(html, "rule-row")
  assert_contains(html, "is-selected")
  assert_contains(html, "aria-expanded=\"true\"")
}

pub fn automation_rule_list_activation_keys_match_button_behavior_test() {
  let assert True = rule_list.is_rule_row_activation_key("Enter")
  let assert True = rule_list.is_rule_row_activation_key(" ")
  let assert False = rule_list.is_rule_row_activation_key("Spacebar")
  let assert False = rule_list.is_rule_row_activation_key("ArrowDown")
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
  assert_contains(html, "aria-labelledby=\"automation-rule-panel-title\"")
  assert_contains(html, "New rule")
  assert_contains(html, "When")
  assert_contains(html, "Any task type")
  assert_contains(html, "Bug")
  assert_contains(html, "Preview")
  assert_contains(html, "When a Bug task is closed")
  assert_contains(html, "Create work from")
  assert_contains(html, "data-testid=\"automation-template-search\"")
  assert_contains(html, "data-testid=\"automation-template-picker\"")
  assert_contains(html, "data-testid=\"automation-rule-create-template\"")
  assert_contains(html, "id=\"automation-create-template-trigger\"")
  assert_contains(html, "Create Template")
  assert_contains(html, "Follow-up task")
  assert_contains(html, "Manual QA review")
  assert_contains(html, "Bug - P3")
  assert_contains(html, "It will create &quot;Follow-up task&quot;")
  assert_not_contains(html, "rule-crud-dialog")
  assert_not_contains(html, "Resource Type")
  assert_not_contains(html, "Target State")
}

pub fn automation_rule_builder_opens_template_panel_without_leaving_builder_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        template_panel_open: True,
        template_panel: div(
          [
            attribute.class("automation-template-panel"),
            attribute.attribute("data-testid", "automation-template-panel"),
          ],
          [text("template panel")],
        ),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Follow-up when bug closes",
          rule_form_subject: "task",
          rule_form_task_type_id: "5",
          rule_form_event: "task_completed",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "data-testid=\"automation-rule-builder\"")
  assert_contains(html, "data-testid=\"automation-template-panel\"")
  assert_contains(html, "template panel")
  assert_contains(html, "inert")
  assert_contains(html, "aria-hidden=\"true\"")
}

pub fn automation_rule_builder_offers_only_supported_task_events_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Follow-up when task changes",
          rule_form_subject: "task",
          rule_form_task_type_id: "",
          rule_form_event: "task_created",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "value=\"task_created\"")
  assert_contains(html, "value=\"task_claimed\"")
  assert_contains(html, "value=\"task_released\"")
  assert_contains(html, "value=\"task_completed\"")
  assert_contains(html, ">is created<")
  assert_contains(html, ">is claimed<")
  assert_contains(html, ">is released<")
  assert_contains(html, ">is closed<")
  assert_not_contains(html, "task_blocked")
  assert_not_contains(html, "task_unblocked")
  assert_not_contains(html, "task_due")
  assert_not_contains(html, "due date")
  assert_not_contains(html, ">is blocked<")
  assert_not_contains(html, ">is unblocked<")
}

pub fn automation_rule_builder_offers_only_supported_card_events_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Follow-up when card changes",
          rule_form_subject: "card",
          rule_form_event: "card_activated",
          rule_form_card_scope: "",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "value=\"card_activated\"")
  assert_contains(html, "value=\"card_closed\"")
  assert_contains(html, ">is activated<")
  assert_contains(html, ">is closed<")
  assert_not_contains(html, "task_created")
  assert_not_contains(html, "task_claimed")
  assert_not_contains(html, "task_released")
  assert_not_contains(html, "task_completed")
  assert_not_contains(html, "subtree")
  assert_not_contains(html, "card_type")
}

pub fn automation_rule_builder_disables_save_for_invalid_template_variables_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        task_templates_project: Loaded([card_variable_template()]),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Follow-up when bug closes",
          rule_form_subject: "task",
          rule_form_task_type_id: "5",
          rule_form_event: "task_completed",
          rule_form_template_id: "14",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Card follow-up")
  assert_contains(html, "Review {{card_title}}")
  assert_contains(
    html,
    "This template uses variables unavailable for the selected trigger: {{card_title}}.",
  )
  assert_contains(html, "role=\"alert\"")
  assert_contains(html, "disabled")
}

pub fn automation_rule_list_localizes_rule_builder_controls_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        locale: locale.Es,
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Follow-up when bug closes",
          rule_form_subject: "card",
          rule_form_event: "card_activated",
          rule_form_card_scope: "",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Nueva regla")
  assert_contains(html, "Cuando")
  assert_contains(html, "Evento")
  assert_contains(html, "se activa")
  assert_contains(html, "aria-label=\"Alcance de automatización de tarjeta\"")
  assert_contains(html, ">Cualquier tarjeta<")
  assert_contains(html, ">Tarjetas de nivel: Initiative<")
  assert_contains(html, ">Tarjetas de nivel: Feature<")
  assert_contains(html, "Crear trabajo desde")
  assert_contains(html, "aria-label=\"Plantilla de tarea de la regla\"")
  assert_contains(html, "Elige una plantilla")
  assert_contains(html, "Vista previa")
  assert_contains(
    html,
    "Cuando cualquier tarjeta se active, se creará trabajo en el Pool.",
  )
  assert_contains(
    html,
    "Creará &quot;Follow-up task&quot; como trabajo disponible.",
  )
  assert_contains(
    html,
    "Aviso: activar una tarjeta con muchas subtarjetas puede crear mucho trabajo en el Pool.",
  )
  assert_not_contains(html, "Card automation scope")
  assert_not_contains(html, "Create work from")
  assert_not_contains(html, "Choose a template")
  assert_not_contains(html, ">Preview<")
  assert_not_contains(html, "When any card is activated")
  assert_not_contains(html, "It will create")
}

pub fn automation_rule_list_template_picker_filters_and_previews_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        task_templates_project: Loaded([task_template(), docs_template()]),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Follow-up when bug closes",
          rule_form_subject: "task",
          rule_form_task_type_id: "5",
          rule_form_event: "task_completed",
          rule_form_template_search: "Follow",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Search templates")
  assert_contains(html, "value=\"Follow\"")
  assert_contains(html, "Follow-up task")
  assert_contains(html, "Manual QA review")
  assert_not_contains(html, "Docs sweep")
}

pub fn automation_rule_list_template_picker_empty_filter_state_test() {
  let html =
    rule_list.view(
      rule_list.Config(
        ..config(),
        task_templates_project: Loaded([task_template(), docs_template()]),
        rules: admin_rules.Model(
          ..rules_state(),
          rules_dialog_mode: opt.Some(admin_rules.RuleDialogCreate),
          rule_form_name: "Follow-up when bug closes",
          rule_form_subject: "task",
          rule_form_task_type_id: "5",
          rule_form_event: "task_completed",
          rule_form_template_search: "Missing",
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "No templates match this search.")
  assert_not_contains(html, "Follow-up task")
  assert_not_contains(html, "Docs sweep")
}
