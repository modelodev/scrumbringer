import gleam/option as opt
import lustre/element
import support/render_assertions

import domain/capability.{Capability}
import domain/project.{Project}
import domain/project_role.{Manager}
import domain/remote.{Loaded}
import domain/task_type.{TaskType}
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
  Project(
    id: 1,
    name: "Project Alpha",
    my_role: Manager,
    created_at: "2026-01-01",
    members_count: 2,
    card_depth_names: [],
    healthy_pool_limit: 20,
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
          capabilities: Loaded([Capability(id: 1, name: "Backend")]),
        ),
        task_types: admin_task_types.Model(
          ..admin.task_types,
          task_types: Loaded([
            TaskType(
              id: 99,
              name: "Bug",
              icon: "bug-ant",
              capability_id: opt.Some(1),
              tasks_count: 7,
            ),
          ]),
        ),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> element.to_document_string

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
            TaskType(
              id: 20,
              name: "Chore",
              icon: "wrench",
              capability_id: opt.None,
              tasks_count: 0,
            ),
          ]),
        ),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> element.to_document_string

  render_assertions.contains(html, ">None<")
}

pub fn icon_picker_trigger_hides_slug_test() {
  let html =
    task_type_crud_dialog.view_create_dialog_for_test(En)
    |> element.to_document_string

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
            TaskType(
              id: 1234,
              name: "Infra",
              icon: "bolt",
              capability_id: opt.None,
              tasks_count: 2,
            ),
          ]),
        ),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> element.to_document_string

  render_assertions.not_contains(html, ">1234<")
}

pub fn task_type_create_dialog_shows_create_copy_and_optional_label_test() {
  let html =
    task_type_crud_dialog.view_create_dialog_for_test(Es)
    |> element.to_document_string

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
      TaskType(
        id: 8,
        name: "Bug",
        icon: "bug-ant",
        capability_id: opt.None,
        tasks_count: 0,
      ),
    )
    |> element.to_document_string

  render_assertions.contains(html, "Edit Task Type")
  render_assertions.contains(html, "edit-name")
  render_assertions.contains(html, "form-group-optional")
  render_assertions.contains(html, "edit-capability")
  render_assertions.contains(html, "icon-picker-trigger")
}
