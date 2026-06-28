import gleam/int
import gleam/option as opt
import gleam/set
import lustre/attribute
import lustre/element
import lustre/element/html.{div, text}
import support/render_assertions

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

  render_assertions.contains(html, "Card automation scope")
  render_assertions.contains(html, "inert")
  render_assertions.contains(html, "aria-hidden=\"true\"")
  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(
    html,
    "aria-labelledby=\"automation-rule-panel-title\"",
  )
  render_assertions.contains(html, "id=\"automation-rule-panel-title\"")
  render_assertions.contains(html, "aria-label=\"Name\"")
  render_assertions.contains(html, "autofocus")
  render_assertions.not_contains(
    html,
    "id=\"automation-rule-panel-title\" tabindex=\"-1\"",
  )
  render_assertions.contains(html, "aria-keyshortcuts=\"Escape\"")
  render_assertions.contains(html, "tabindex=\"-1\"")
  render_assertions.contains(html, "aria-label=\"Goal\"")
  render_assertions.contains(html, "aria-label=\"Rule subject\"")
  render_assertions.contains(html, "aria-label=\"Event\"")
  render_assertions.contains(html, "aria-label=\"Rule task template\"")
  render_assertions.contains(html, ">Any card<")
  render_assertions.contains(html, ">Cards at level: Initiative<")
  render_assertions.contains(html, ">Cards at level: Feature<")
  render_assertions.contains(html, ">Cards at level: Story<")
  render_assertions.contains(html, "value=\"2\"")
  render_assertions.contains(html, "When a Feature is closed")
  render_assertions.not_contains(html, "type=\"number\"")
  render_assertions.not_contains(html, "subtree")
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

  render_assertions.contains(html, "Card level 9 is no longer available.")
  render_assertions.contains(html, "Choose an existing card level or Any card.")
  render_assertions.contains(html, "role=\"alert\"")
  render_assertions.contains(html, "disabled")
  render_assertions.not_contains(html, "value=\"9\" selected")
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

  render_assertions.contains(html, "automation-rule-panel-danger")
  render_assertions.contains(html, "inert")
  render_assertions.contains(html, "aria-hidden=\"true\"")
  render_assertions.contains(
    html,
    "aria-labelledby=\"automation-rule-panel-title\"",
  )
  render_assertions.contains(html, "id=\"automation-rule-panel-title\"")
  render_assertions.contains(html, "tabindex=\"-1\"")
  render_assertions.contains(html, "autofocus")
  render_assertions.contains(html, "Delete rule")
}

pub fn automation_rule_list_renders_rules_from_config_without_root_model_test() {
  let html =
    rule_list.view(config())
    |> element.to_document_string

  render_assertions.contains(html, "Rules - Release automation")
  render_assertions.contains(html, "Back to Automations")
  render_assertions.contains(html, "automation-rules-heading")
  render_assertions.contains(html, automation_focus.create_rule_trigger_id)
  render_assertions.contains(html, "automation-rule-list")
  render_assertions.contains(html, "Close bug workflow")
  render_assertions.contains(html, "When a Bug task is closed")
  render_assertions.contains(html, "-&gt; Create Bug triage in the Pool")
  render_assertions.contains(html, "Engine:")
  render_assertions.contains(html, "Release automation")
  render_assertions.contains(html, "Template:")
  render_assertions.contains(html, "Created:")
  render_assertions.contains(html, "Ignored:")
  render_assertions.not_contains(html, "data-table")
  render_assertions.not_contains(html, "<table")
  render_assertions.not_contains(html, "Automatizacion")
  render_assertions.not_contains(html, "Resource Type")
  render_assertions.not_contains(html, "Target State")
  render_assertions.not_contains(html, "Suppressed")
  render_assertions.not_contains(html, "admin-section-header")
  render_assertions.contains(html, "Bug triage")
  render_assertions.contains(html, "4")
  render_assertions.contains(html, "2")
  render_assertions.contains(html, "btn-view-action")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.contains(html, automation_focus.rule_edit_trigger_id(9))
  render_assertions.contains(html, automation_focus.rule_delete_trigger_id(9))
  render_assertions.not_contains(html, "inert")
  render_assertions.not_contains(html, "btn btn-sm btn-primary")
}

pub fn automation_rule_list_localizes_rule_meta_labels_test() {
  let html =
    rule_list.view(rule_list.Config(..config(), locale: locale.Es))
    |> element.to_document_string

  render_assertions.contains(html, "Motor:")
  render_assertions.contains(html, "Plantilla:")
  render_assertions.contains(html, "Creadas:")
  render_assertions.contains(html, "Ignoradas:")
  render_assertions.not_contains(html, "Engine:")
  render_assertions.not_contains(html, "Template:")
  render_assertions.not_contains(html, "Created:")
  render_assertions.not_contains(html, "Ignored:")
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

  render_assertions.contains(html, "No rules yet")
}

pub fn automation_rule_list_marks_selected_rule_test() {
  let html =
    rule_list.view(rule_list.Config(..config(), selected_rule_id: opt.Some(9)))
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"automation-rule-row\"")
  render_assertions.contains(html, "role=\"button\"")
  render_assertions.contains(html, "tabindex=\"0\"")
  render_assertions.contains(html, "data-selected=\"true\"")
  render_assertions.contains(html, "rule-row")
  render_assertions.contains(html, "is-selected")
  render_assertions.contains(html, "aria-expanded=\"true\"")
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
          rule_form_event: "task_closed",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "automation-rule-panel")
  render_assertions.contains(html, "data-testid=\"automation-rule-builder\"")
  render_assertions.contains(
    html,
    "aria-labelledby=\"automation-rule-panel-title\"",
  )
  render_assertions.contains(html, "New rule")
  render_assertions.contains(html, "When")
  render_assertions.contains(html, "Any task type")
  render_assertions.contains(html, "Bug")
  render_assertions.contains(html, "Preview")
  render_assertions.contains(html, "When a Bug task is closed")
  render_assertions.contains(html, "Create work from")
  render_assertions.contains(html, "data-testid=\"automation-template-search\"")
  render_assertions.contains(html, "data-testid=\"automation-template-picker\"")
  render_assertions.contains(
    html,
    "data-testid=\"automation-rule-create-template\"",
  )
  render_assertions.contains(html, "id=\"automation-create-template-trigger\"")
  render_assertions.contains(html, "Create Template")
  render_assertions.contains(html, "Follow-up task")
  render_assertions.contains(html, "Manual QA review")
  render_assertions.contains(html, "Bug - P3")
  render_assertions.contains(html, "It will create &quot;Follow-up task&quot;")
  render_assertions.not_contains(html, "rule-crud-dialog")
  render_assertions.not_contains(html, "Resource Type")
  render_assertions.not_contains(html, "Target State")
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
          rule_form_event: "task_closed",
        ),
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"automation-rule-builder\"")
  render_assertions.contains(html, "data-testid=\"automation-template-panel\"")
  render_assertions.contains(html, "template panel")
  render_assertions.contains(html, "inert")
  render_assertions.contains(html, "aria-hidden=\"true\"")
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

  render_assertions.contains(html, "value=\"task_created\"")
  render_assertions.contains(html, "value=\"task_claimed\"")
  render_assertions.contains(html, "value=\"task_released\"")
  render_assertions.contains(html, "value=\"task_closed\"")
  render_assertions.contains(html, ">is created<")
  render_assertions.contains(html, ">is claimed<")
  render_assertions.contains(html, ">is released<")
  render_assertions.contains(html, ">is closed<")
  render_assertions.not_contains(html, "task_blocked")
  render_assertions.not_contains(html, "task_unblocked")
  render_assertions.not_contains(html, "task_due")
  render_assertions.not_contains(html, "due date")
  render_assertions.not_contains(html, ">is blocked<")
  render_assertions.not_contains(html, ">is unblocked<")
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

  render_assertions.contains(html, "value=\"card_activated\"")
  render_assertions.contains(html, "value=\"card_closed\"")
  render_assertions.contains(html, ">is activated<")
  render_assertions.contains(html, ">is closed<")
  render_assertions.not_contains(html, "task_created")
  render_assertions.not_contains(html, "task_claimed")
  render_assertions.not_contains(html, "task_released")
  render_assertions.not_contains(html, "task_closed")
  render_assertions.not_contains(html, "subtree")
  render_assertions.not_contains(html, "card_type")
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
          rule_form_event: "task_closed",
          rule_form_template_id: "14",
        ),
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Card follow-up")
  render_assertions.contains(html, "Review {{card_title}}")
  render_assertions.contains(
    html,
    "This template uses variables unavailable for the selected trigger: {{card_title}}.",
  )
  render_assertions.contains(html, "role=\"alert\"")
  render_assertions.contains(html, "disabled")
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

  render_assertions.contains(html, "Nueva regla")
  render_assertions.contains(html, "Cuando")
  render_assertions.contains(html, "Evento")
  render_assertions.contains(html, "se activa")
  render_assertions.contains(
    html,
    "aria-label=\"Alcance de automatización de tarjeta\"",
  )
  render_assertions.contains(html, ">Cualquier tarjeta<")
  render_assertions.contains(html, ">Tarjetas de nivel: Initiative<")
  render_assertions.contains(html, ">Tarjetas de nivel: Feature<")
  render_assertions.contains(html, "Crear trabajo desde")
  render_assertions.contains(
    html,
    "aria-label=\"Plantilla de tarea de la regla\"",
  )
  render_assertions.contains(html, "Elige una plantilla")
  render_assertions.contains(html, "Vista previa")
  render_assertions.contains(
    html,
    "Cuando cualquier tarjeta se active, se creará trabajo en el Pool.",
  )
  render_assertions.contains(
    html,
    "Creará &quot;Follow-up task&quot; como trabajo disponible.",
  )
  render_assertions.contains(
    html,
    "Aviso: activar una tarjeta con muchas subtarjetas puede crear mucho trabajo en el Pool.",
  )
  render_assertions.not_contains(html, "Card automation scope")
  render_assertions.not_contains(html, "Create work from")
  render_assertions.not_contains(html, "Choose a template")
  render_assertions.not_contains(html, ">Preview<")
  render_assertions.not_contains(html, "When any card is activated")
  render_assertions.not_contains(html, "It will create")
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
          rule_form_event: "task_closed",
          rule_form_template_search: "Follow",
          rule_form_template_id: "12",
        ),
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Search templates")
  render_assertions.contains(html, "value=\"Follow\"")
  render_assertions.contains(html, "Follow-up task")
  render_assertions.contains(html, "Manual QA review")
  render_assertions.not_contains(html, "Docs sweep")
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
          rule_form_event: "task_closed",
          rule_form_template_search: "Missing",
        ),
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "No templates match this search.")
  render_assertions.not_contains(html, "Follow-up task")
  render_assertions.not_contains(html, "Docs sweep")
}
