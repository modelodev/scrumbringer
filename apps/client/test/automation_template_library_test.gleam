import gleam/int
import gleam/option as opt
import support/render_assertions

import domain/remote.{Loaded}
import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{type TaskTemplate, TaskTemplate}
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/features/automations/focus_target as automation_focus
import scrumbringer_client/features/automations/template_library
import scrumbringer_client/i18n/locale

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
    |> render_assertions.html

  render_assertions.contains(html, "Template library")
  render_assertions.contains(html, "filter-bar automation-templates-filters")
  render_assertions.contains(html, "data-testid=\"automation-template-picker\"")
  render_assertions.contains(html, automation_focus.create_template_trigger_id)
  render_assertions.contains(html, "data-testid=\"automation-template-search\"")
  render_assertions.contains(html, "data-testid=\"automation-template-row\"")
  render_assertions.contains(html, "Regression checklist")
  render_assertions.contains(html, "Review backlog")
  render_assertions.contains(html, "Bug")
  render_assertions.contains(html, "4")
  render_assertions.contains(html, "Uses")
  render_assertions.contains(html, "Created")
  render_assertions.contains(html, "Last")
  render_assertions.contains(html, "2026-06-08T10:00:00Z")
  render_assertions.contains(html, "Never")
  render_assertions.contains(html, "automation-template-unused-badge")
  render_assertions.contains(html, "Unused")
  render_assertions.contains(html, "template-edit-btn")
  render_assertions.contains(html, "template-delete-btn")
  render_assertions.contains(html, automation_focus.template_edit_trigger_id(7))
  render_assertions.contains(
    html,
    automation_focus.template_delete_trigger_id(7),
  )
  render_assertions.contains(html, automation_focus.template_edit_trigger_id(8))
  render_assertions.contains(
    html,
    automation_focus.template_delete_trigger_id(8),
  )
  render_assertions.not_contains(html, "inert")
  render_assertions.not_contains(html, "section-header")
  render_assertions.not_contains(html, "info-callout-link")
  render_assertions.not_contains(html, "task-template-crud-dialog")
}

pub fn automation_template_library_localizes_unused_template_warning_test() {
  let html =
    template_library.view(
      template_library.Config(..config(), locale: locale.Es),
    )
    |> render_assertions.html

  render_assertions.contains(html, "Usos")
  render_assertions.contains(html, "Sin uso")
  render_assertions.contains(html, "Creadas")
  render_assertions.contains(html, "Última")
  render_assertions.contains(html, "Nunca")
  render_assertions.not_contains(html, "Uses")
  render_assertions.not_contains(html, "Unused")
  render_assertions.not_contains(html, "Never")
}

pub fn automation_template_library_renders_empty_state_without_root_model_test() {
  let html =
    template_library.view(
      template_library.Config(..config(), templates: Loaded([])),
    )
    |> render_assertions.html

  render_assertions.contains(html, "No templates yet")
}

pub fn automation_template_library_filters_library_by_search_query_test() {
  let html =
    template_library.view(
      template_library.Config(..config(), search_query: "missing"),
    )
    |> render_assertions.html

  render_assertions.contains(html, "No templates yet")
  render_assertions.not_contains(html, "Regression checklist")
}

pub fn automation_template_library_marks_selected_template_test() {
  let html =
    template_library.view(
      template_library.Config(..config(), selected_template_id: opt.Some(7)),
    )
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"automation-template-row\"")
  render_assertions.contains(html, "data-selected=\"true\"")
  render_assertions.contains(html, "automation-template-row is-selected")
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
    |> render_assertions.html

  render_assertions.contains(html, "automation-template-panel")
  render_assertions.contains(html, "inert")
  render_assertions.contains(html, "aria-hidden=\"true\"")
  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(
    html,
    "aria-labelledby=\"automation-template-panel-title\"",
  )
  render_assertions.contains(html, "id=\"automation-template-panel-title\"")
  render_assertions.contains(html, "data-testid=\"automation-template-name\"")
  render_assertions.contains(html, "autofocus")
  render_assertions.not_contains(
    html,
    "id=\"automation-template-panel-title\" tabindex=\"-1\"",
  )
  render_assertions.contains(html, "aria-keyshortcuts=\"Escape\"")
  render_assertions.contains(html, "tabindex=\"-1\"")
  render_assertions.contains(html, "Create Template")
  render_assertions.contains(html, "automation-template-name")
  render_assertions.contains(html, "aria-label=\"Name\"")
  render_assertions.contains(html, "aria-label=\"Description\"")
  render_assertions.contains(html, "aria-label=\"Type\"")
  render_assertions.contains(html, "aria-label=\"Priority\"")
  render_assertions.contains(html, "QA checklist")
  render_assertions.contains(html, "Check {{project}}")
  render_assertions.contains(html, "Available variables")
  render_assertions.contains(html, "Use variables in the description")
  render_assertions.contains(
    html,
    "data-testid=\"automation-template-variable-chip\"",
  )
  render_assertions.contains(html, "data-variable=\"{{origin}}\"")
  render_assertions.contains(html, "data-variable=\"{{trigger}}\"")
  render_assertions.contains(html, "data-variable=\"{{project}}\"")
  render_assertions.contains(html, "data-variable=\"{{user}}\"")
  render_assertions.contains(html, "data-variable=\"{{task_title}}\"")
  render_assertions.contains(html, "data-variable=\"{{task_type}}\"")
  render_assertions.contains(html, "data-variable=\"{{card_title}}\"")
  render_assertions.contains(html, "data-variable=\"{{card_level}}\"")
  render_assertions.contains(html, "aria-label=\"Insert variable {{origin}}\"")
  render_assertions.contains(html, "Select type")
  render_assertions.contains(html, "Cancel")
  render_assertions.not_contains(html, "{{father}}")
  render_assertions.not_contains(html, "{{due_date}}")
  render_assertions.not_contains(html, "New template")
  render_assertions.not_contains(html, "Select task type")
  render_assertions.not_contains(html, "task-template-crud-dialog")
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
    |> render_assertions.html

  render_assertions.contains(html, "Delete Template")
  render_assertions.contains(html, "inert")
  render_assertions.contains(html, "aria-hidden=\"true\"")
  render_assertions.contains(html, "role=\"dialog\"")
  render_assertions.contains(html, "aria-modal=\"true\"")
  render_assertions.contains(
    html,
    "aria-labelledby=\"automation-template-panel-title\"",
  )
  render_assertions.contains(html, "id=\"automation-template-panel-title\"")
  render_assertions.contains(html, "tabindex=\"-1\"")
  render_assertions.contains(html, "autofocus")
  render_assertions.contains(html, "aria-keyshortcuts=\"Escape\"")
  render_assertions.contains(html, "tabindex=\"-1\"")
  render_assertions.contains(
    html,
    "Delete template &quot;Regression checklist&quot;?",
  )
  render_assertions.contains(html, "Regression checklist")
  render_assertions.contains(
    html,
    "Rules using this template should be paused or updated first.",
  )
  render_assertions.not_contains(html, "task-template-crud-dialog")
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
    |> render_assertions.html

  render_assertions.contains(html, "Edit Template")
  render_assertions.contains(html, "automation-template-panel__warning")
  render_assertions.contains(html, "role=\"note\"")
  render_assertions.contains(
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
    |> render_assertions.html

  render_assertions.contains(html, "Edit Template")
  render_assertions.not_contains(html, "automation-template-panel__warning")
  render_assertions.not_contains(
    html,
    "Changes affect only future generated tasks",
  )
}
