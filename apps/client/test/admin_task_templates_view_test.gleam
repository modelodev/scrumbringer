import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/remote.{Loaded}
import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{type TaskTemplate, TaskTemplate}
import scrumbringer_client/features/admin/task_templates_view
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
    rules_count: 0,
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

fn config() -> task_templates_view.Config(String) {
  task_templates_view.Config(
    locale: locale.En,
    selected_project: opt.None,
    selected_project_id: opt.Some(3),
    templates: Loaded([sample_template()]),
    dialog_mode: opt.None,
    task_types: Loaded([sample_task_type()]),
    search_query: "",
    on_create_clicked: "create",
    on_edit_clicked: fn(template) { "edit-" <> template.name },
    on_delete_clicked: fn(template) { "delete-" <> template.name },
    on_search_changed: fn(value) { "search-" <> value },
    on_created: fn(template) { "created-" <> template.name },
    on_updated: fn(template) { "updated-" <> template.name },
    on_deleted: fn(id) { "deleted-" <> int.to_string(id) },
    on_closed: "closed",
  )
}

pub fn task_templates_view_renders_from_config_without_root_model_test() {
  let html =
    task_templates_view.view_task_templates(config())
    |> element.to_document_string

  assert_contains(html, "Template library")
  assert_contains(html, "filter-bar automation-templates-filters")
  assert_contains(html, "data-testid=\"automation-template-picker\"")
  assert_contains(html, "data-testid=\"automation-template-search\"")
  assert_contains(html, "data-testid=\"automation-template-row\"")
  assert_contains(html, "Regression checklist")
  assert_contains(html, "Bug")
  assert_contains(html, "4")
  assert_contains(html, "template-edit-btn")
  assert_contains(html, "template-delete-btn")
  assert_not_contains(html, "section-header")
  assert_not_contains(html, "info-callout-link")
}

pub fn task_templates_view_renders_empty_state_without_root_model_test() {
  let html =
    task_templates_view.view_task_templates(
      task_templates_view.Config(..config(), templates: Loaded([])),
    )
    |> element.to_document_string

  assert_contains(html, "No templates yet")
}

pub fn task_templates_view_filters_library_by_search_query_test() {
  let html =
    task_templates_view.view_task_templates(
      task_templates_view.Config(..config(), search_query: "missing"),
    )
    |> element.to_document_string

  assert_contains(html, "No templates yet")
  assert_not_contains(html, "Regression checklist")
}
