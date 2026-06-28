import gleam/option as opt
import support/domain_fixtures
import support/render_assertions

import domain/project.{Project}
import domain/remote.{Loaded}
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/client_state.{type Model, default_model, update_admin}
import scrumbringer_client/client_state/admin.{AdminModel}
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/components/task_type_crud_dialog
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/i18n/locale.{En, Es}

fn base_model() -> Model {
  default_model()
}

fn sample_project() {
  Project(..domain_fixtures.project(1, "Project Alpha"), members_count: 2)
}

fn task_type(
  id: Int,
  name: String,
  icon: String,
  capability_id: opt.Option(Int),
  tasks_count: Int,
) -> TaskType {
  TaskType(
    ..domain_fixtures.task_type(id, name),
    icon: icon,
    capability_id: capability_id,
    tasks_count: tasks_count,
  )
}

pub fn task_types_table_renders_capability_name_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      AdminModel(
        ..admin,
        capabilities: admin_capabilities.Model(
          ..admin.capabilities,
          capabilities: Loaded([domain_fixtures.capability(1, "Backend")]),
        ),
        task_types: admin_task_types.Model(
          ..admin.task_types,
          task_types: Loaded([
            task_type(99, "Bug", "bug-ant", opt.Some(1), 7),
          ]),
        ),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> render_assertions.html

  render_assertions.contains(html, "Backend")
  render_assertions.not_contains(html, ">1<")
  render_assertions.contains(html, "cell-number")
  render_assertions.contains(html, "aria-label=\"Edit Task Type\"")
  render_assertions.contains(html, "btn-delete-blocked")
  render_assertions.contains(
    html,
    "data-tooltip=\"Cannot delete: has 7 tasks\"",
  )
  render_assertions.contains(html, "aria-disabled=\"true\"")
}

pub fn task_types_table_renders_none_when_no_capability_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      AdminModel(
        ..admin,
        task_types: admin_task_types.Model(
          ..admin.task_types,
          task_types: Loaded([
            task_type(20, "Chore", "wrench", opt.None, 0),
          ]),
        ),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> render_assertions.html

  render_assertions.contains(html, ">None<")
}

pub fn icon_picker_trigger_hides_slug_test() {
  let html =
    task_type_crud_dialog.view_create_dialog_for_test(En)
    |> render_assertions.html

  render_assertions.not_contains(html, "clipboard-document-list")
}

pub fn task_types_table_does_not_render_ids_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      AdminModel(
        ..admin,
        task_types: admin_task_types.Model(
          ..admin.task_types,
          task_types: Loaded([
            task_type(1234, "Infra", "bolt", opt.None, 2),
          ]),
        ),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> render_assertions.html

  render_assertions.not_contains(html, ">1234<")
}

pub fn task_type_create_dialog_shows_create_copy_and_optional_label_test() {
  let html =
    task_type_crud_dialog.view_create_dialog_for_test(Es)
    |> render_assertions.html

  render_assertions.contains(html, "Crear tipo")
  render_assertions.contains(html, "form-group-optional")
  render_assertions.contains(html, "Opcionales")
  render_assertions.contains(html, "create-name")
  render_assertions.contains(html, "Ej: Bug, Mejora, Documentacion")
  render_assertions.contains(html, "create-capability")
  render_assertions.contains(html, "icon-picker-trigger")
}

pub fn task_type_edit_dialog_uses_shared_optional_fields_test() {
  let html =
    task_type_crud_dialog.view_edit_dialog_for_test(
      En,
      domain_fixtures.task_type(8, "Bug"),
    )
    |> render_assertions.html

  render_assertions.contains(html, "Edit Task Type")
  render_assertions.contains(html, "edit-name")
  render_assertions.contains(html, "form-group-optional")
  render_assertions.contains(html, "edit-capability")
  render_assertions.contains(html, "icon-picker-trigger")
}
