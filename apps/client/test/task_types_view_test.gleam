import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/capability.{Capability}
import domain/remote.{Loaded}
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/task_types_view
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn task_type(id: Int, name: String, capability_id: opt.Option(Int)) -> TaskType {
  TaskType(
    id: id,
    name: name,
    icon: "bug-ant",
    capability_id: capability_id,
    tasks_count: 3,
  )
}

fn config(model: admin_task_types.Model) -> task_types_view.Config(String) {
  task_types_view.Config(
    locale: locale.En,
    theme: theme.Default,
    project_id: 7,
    project_name: "Roadmap",
    model: model,
    capabilities: Loaded([Capability(id: 1, name: "Backend")]),
    on_create_opened: "create-opened",
    on_edit_opened: fn(task_type) { "edit:" <> int.to_string(task_type.id) },
    on_delete_opened: fn(task_type) { "delete:" <> int.to_string(task_type.id) },
    on_dialog_closed: "dialog-closed",
    on_crud_created: fn(task_type) { "created:" <> int.to_string(task_type.id) },
    on_crud_updated: fn(task_type) { "updated:" <> int.to_string(task_type.id) },
    on_crud_deleted: fn(id) { "deleted:" <> int.to_string(id) },
  )
}

pub fn task_types_view_renders_list_from_config_without_root_model_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types: Loaded([
        task_type(5, "Bug", opt.Some(1)),
        task_type(6, "Spike", opt.None),
      ]),
    )

  let html =
    task_types_view.view(config(model))
    |> element.to_document_string

  assert_contains(html, "Task Types - Roadmap")
  assert_contains(html, "Create type")
  assert_contains(html, "Bug")
  assert_contains(html, "Spike")
  assert_contains(html, "Backend")
  assert_contains(html, ">None<")
  assert_contains(html, "task-type-edit-btn")
  assert_contains(html, "task-type-delete-btn")
}

pub fn task_types_view_renders_crud_dialog_from_config_without_root_model_test() {
  let model =
    admin_task_types.Model(
      ..admin_task_types.default_model(),
      task_types_dialog_mode: opt.Some(state_types.TaskTypeDialogCreate),
    )

  let html =
    task_types_view.view(config(model))
    |> element.to_document_string

  assert_contains(html, "task-type-crud-dialog")
  assert_contains(html, "locale=\"en\"")
  assert_contains(html, "project-id=\"7\"")
  assert_contains(html, "mode=\"create\"")
}
