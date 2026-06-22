import gleam/option as opt
import gleam/string
import lustre/element

import domain/task_type.{type TaskType, TaskType}
import domain/workflow.{type TaskTemplate, TaskTemplate}
import scrumbringer_client/components/task_template_crud_dialog as dialog
import scrumbringer_client/i18n/locale.{En}

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
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

fn sample_template() -> TaskTemplate {
  TaskTemplate(
    id: 5,
    org_id: 1,
    project_id: opt.Some(1),
    name: "Regression",
    description: opt.Some("Check {{project}}"),
    type_id: 2,
    type_name: "Bug",
    priority: 4,
    created_by: 10,
    created_at: "2026-01-01T00:00:00Z",
    rules_count: 0,
  )
}

pub fn parse_priority_accepts_valid_range_test() {
  let assert Ok(1) = dialog.parse_priority("1")
  let assert Ok(3) = dialog.parse_priority("3")
  let assert Ok(5) = dialog.parse_priority("5")
}

pub fn parse_priority_rejects_non_numeric_values_test() {
  let assert Error(dialog.InvalidPriority("high")) =
    dialog.parse_priority("high")
}

pub fn parse_priority_rejects_values_outside_supported_range_test() {
  let assert Error(dialog.InvalidPriority("0")) = dialog.parse_priority("0")
  let assert Error(dialog.InvalidPriority("6")) = dialog.parse_priority("6")
}

pub fn create_dialog_renders_shared_template_fields_test() {
  let html =
    dialog.view_create_dialog_for_test(En, [
      sample_task_type(),
    ])
    |> element.to_document_string

  assert_contains(html, "template-create-form")
  assert_contains(html, "Template name")
  assert_contains(html, "Template description")
  assert_contains(html, "Available variables")
  assert_contains(html, "{{origin}}, {{trigger}}, {{project}}, {{user}}")
  assert_contains(html, "Bug")
  assert_contains(html, "3 - Medium")
}

pub fn edit_dialog_renders_shared_template_fields_test() {
  let html =
    dialog.view_edit_dialog_for_test(En, sample_template(), [
      sample_task_type(),
    ])
    |> element.to_document_string

  assert_contains(html, "template-edit-form")
  assert_contains(html, "Regression")
  assert_contains(html, "Check {{project}}")
  assert_contains(html, "Bug")
  assert_contains(html, "4 - Low")
}
