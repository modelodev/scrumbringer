import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/remote.{Loaded}
import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{type TaskTemplate, TaskTemplate}
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/features/automations/template_library
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn sample_template() -> TaskTemplate {
  TaskTemplate(
    id: 7,
    org_id: 1,
    project_id: opt.Some(3),
    name: "Regression checklist",
    description: opt.Some("Run smoke checks"),
    type_id: 2,
    type_name: "Bug",
    priority: 4,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 2,
    created_tasks_count: 8,
    last_execution_at: opt.Some("2026-06-08T10:00:00Z"),
  )
}

fn unused_template() -> TaskTemplate {
  TaskTemplate(
    id: 8,
    org_id: 1,
    project_id: opt.Some(3),
    name: "Review backlog",
    description: opt.Some("Review with no rules"),
    type_id: 2,
    type_name: "Bug",
    priority: 3,
    created_by: 1,
    created_at: "2026-01-02T00:00:00Z",
    rules_count: 0,
    created_tasks_count: 0,
    last_execution_at: opt.None,
  )
}

fn sample_task_type() -> TaskType {
  TaskType(
    id: 2,
    name: "Bug",
    icon: "bug-ant",
    capability_id: opt.None,
    tasks_count: 0,
  )
}

fn config() -> template_library.Config(String) {
  template_library.Config(
    locale: locale.En,
    selected_project: opt.None,
    selected_project_id: opt.Some(3),
    templates: Loaded([sample_template(), unused_template()]),
    selected_template_id: opt.None,
    dialog_mode: opt.None,
    task_types: Loaded([sample_task_type()]),
    search_query: "",
    form_name: "",
    form_description: "",
    form_type_id: "",
    form_priority: "3",
    form_submitting: False,
    form_error: opt.None,
    on_create_clicked: "create",
    on_edit_clicked: fn(template) { "edit-" <> template.name },
    on_delete_clicked: fn(template) { "delete-" <> template.name },
    on_search_changed: fn(value) { "search-" <> value },
    on_name_changed: fn(value) { "name-" <> value },
    on_description_changed: fn(value) { "description-" <> value },
    on_type_changed: fn(value) { "type-" <> value },
    on_priority_changed: fn(value) { "priority-" <> value },
    on_submitted: fn(project_id) {
      case project_id {
        opt.Some(id) -> "submit-" <> int.to_string(id)
        opt.None -> "submit-none"
      }
    },
    on_delete_confirmed: "confirm-delete",
    on_closed: "closed",
  )
}

pub fn automation_template_library_renders_from_config_without_root_model_test() {
  let html =
    template_library.view(config())
    |> element.to_document_string

  assert_contains(html, "Template library")
  assert_contains(html, "filter-bar automation-templates-filters")
  assert_contains(html, "data-testid=\"automation-template-picker\"")
  assert_contains(html, "data-testid=\"automation-template-search\"")
  assert_contains(html, "data-testid=\"automation-template-row\"")
  assert_contains(html, "Regression checklist")
  assert_contains(html, "Review backlog")
  assert_contains(html, "Bug")
  assert_contains(html, "4")
  assert_contains(html, "Uses")
  assert_contains(html, "Created")
  assert_contains(html, "Last")
  assert_contains(html, "2026-06-08T10:00:00Z")
  assert_contains(html, "Never")
  assert_contains(html, "automation-template-unused-badge")
  assert_contains(html, "Unused")
  assert_contains(html, "template-edit-btn")
  assert_contains(html, "template-delete-btn")
  assert_not_contains(html, "section-header")
  assert_not_contains(html, "info-callout-link")
  assert_not_contains(html, "task-template-crud-dialog")
}

pub fn automation_template_library_localizes_unused_template_warning_test() {
  let html =
    template_library.view(
      template_library.Config(..config(), locale: locale.Es),
    )
    |> element.to_document_string

  assert_contains(html, "Usos")
  assert_contains(html, "Sin uso")
  assert_contains(html, "Creadas")
  assert_contains(html, "Última")
  assert_contains(html, "Nunca")
  assert_not_contains(html, "Uses")
  assert_not_contains(html, "Unused")
  assert_not_contains(html, "Never")
}

pub fn automation_template_library_renders_empty_state_without_root_model_test() {
  let html =
    template_library.view(
      template_library.Config(..config(), templates: Loaded([])),
    )
    |> element.to_document_string

  assert_contains(html, "No templates yet")
}

pub fn automation_template_library_filters_library_by_search_query_test() {
  let html =
    template_library.view(
      template_library.Config(..config(), search_query: "missing"),
    )
    |> element.to_document_string

  assert_contains(html, "No templates yet")
  assert_not_contains(html, "Regression checklist")
}

pub fn automation_template_library_marks_selected_template_test() {
  let html =
    template_library.view(
      template_library.Config(..config(), selected_template_id: opt.Some(7)),
    )
    |> element.to_document_string

  assert_contains(html, "data-testid=\"automation-template-row\"")
  assert_contains(html, "data-selected=\"true\"")
  assert_contains(html, "automation-template-row is-selected")
}

pub fn automation_template_library_renders_feature_local_create_panel_test() {
  let html =
    template_library.view(
      template_library.Config(
        ..config(),
        dialog_mode: opt.Some(admin_task_templates.TaskTemplateDialogCreate),
        form_name: "QA checklist",
        form_description: "Check {{project}}",
        form_type_id: "2",
        form_priority: "4",
      ),
    )
    |> element.to_document_string

  assert_contains(html, "automation-template-panel")
  assert_contains(html, "role=\"dialog\"")
  assert_contains(html, "aria-modal=\"true\"")
  assert_contains(html, "aria-labelledby=\"automation-template-panel-title\"")
  assert_contains(html, "id=\"automation-template-panel-title\"")
  assert_contains(html, "data-testid=\"automation-template-name\"")
  assert_contains(html, "autofocus")
  assert_not_contains(
    html,
    "id=\"automation-template-panel-title\" tabindex=\"-1\"",
  )
  assert_contains(html, "aria-keyshortcuts=\"Escape\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_contains(html, "Create Template")
  assert_contains(html, "automation-template-name")
  assert_contains(html, "aria-label=\"Name\"")
  assert_contains(html, "aria-label=\"Description\"")
  assert_contains(html, "aria-label=\"Type\"")
  assert_contains(html, "aria-label=\"Priority\"")
  assert_contains(html, "QA checklist")
  assert_contains(html, "Check {{project}}")
  assert_contains(html, "Available variables")
  assert_contains(html, "Use variables in the description")
  assert_contains(html, "data-testid=\"automation-template-variable-chip\"")
  assert_contains(html, "data-variable=\"{{origin}}\"")
  assert_contains(html, "data-variable=\"{{trigger}}\"")
  assert_contains(html, "data-variable=\"{{project}}\"")
  assert_contains(html, "data-variable=\"{{user}}\"")
  assert_contains(html, "data-variable=\"{{task_title}}\"")
  assert_contains(html, "data-variable=\"{{task_type}}\"")
  assert_contains(html, "data-variable=\"{{card_title}}\"")
  assert_contains(html, "data-variable=\"{{card_level}}\"")
  assert_contains(html, "aria-label=\"Insert variable {{origin}}\"")
  assert_contains(html, "Select type")
  assert_contains(html, "Cancel")
  assert_not_contains(html, "{{father}}")
  assert_not_contains(html, "{{due_date}}")
  assert_not_contains(html, "New template")
  assert_not_contains(html, "Select task type")
  assert_not_contains(html, "task-template-crud-dialog")
}

pub fn automation_template_library_renders_feature_local_delete_panel_test() {
  let html =
    template_library.view(
      template_library.Config(
        ..config(),
        dialog_mode: opt.Some(
          admin_task_templates.TaskTemplateDialogDelete(sample_template()),
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Delete Template")
  assert_contains(html, "role=\"dialog\"")
  assert_contains(html, "aria-modal=\"true\"")
  assert_contains(html, "aria-labelledby=\"automation-template-panel-title\"")
  assert_contains(html, "id=\"automation-template-panel-title\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_contains(html, "autofocus")
  assert_contains(html, "aria-keyshortcuts=\"Escape\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_contains(html, "Delete template &quot;Regression checklist&quot;?")
  assert_contains(html, "Regression checklist")
  assert_contains(
    html,
    "Rules using this template should be paused or updated first.",
  )
  assert_not_contains(html, "task-template-crud-dialog")
}

pub fn automation_template_library_warns_when_editing_used_template_test() {
  let html =
    template_library.view(
      template_library.Config(
        ..config(),
        dialog_mode: opt.Some(
          admin_task_templates.TaskTemplateDialogEdit(sample_template()),
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Edit Template")
  assert_contains(html, "automation-template-panel__warning")
  assert_contains(html, "role=\"note\"")
  assert_contains(
    html,
    "Changes affect only future generated tasks; tasks already created keep their original content and origin.",
  )
}

pub fn automation_template_library_skips_future_warning_for_unused_template_test() {
  let html =
    template_library.view(
      template_library.Config(
        ..config(),
        dialog_mode: opt.Some(
          admin_task_templates.TaskTemplateDialogEdit(unused_template()),
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Edit Template")
  assert_not_contains(html, "automation-template-panel__warning")
  assert_not_contains(html, "Changes affect only future generated tasks")
}
