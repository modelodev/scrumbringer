import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/element

import domain/capability.{Capability}
import domain/project.{Project}
import domain/project_role.{Manager}
import domain/remote.{Loaded}
import domain/task_type.{TaskType}
import scrumbringer_client/client_state.{type Model, default_model, update_admin}
import scrumbringer_client/client_state/admin.{AdminModel}
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
  )
}

pub fn task_types_table_renders_capability_name_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      AdminModel(
        ..admin,
        capabilities: Loaded([Capability(id: 1, name: "Backend")]),
        task_types: Loaded([
          TaskType(
            id: 99,
            name: "Bug",
            icon: "bug-ant",
            capability_id: opt.Some(1),
            tasks_count: 7,
          ),
        ]),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> element.to_document_string

  string.contains(html, "Backend") |> should.be_true
  string.contains(html, ">1<") |> should.be_false
  string.contains(html, "cell-number") |> should.be_true
  string.contains(html, "aria-label=\"Edit Task Type\"") |> should.be_true
  string.contains(html, "aria-label=\"Delete Task Type\"") |> should.be_true
}

pub fn task_types_table_renders_none_when_no_capability_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      AdminModel(
        ..admin,
        task_types: Loaded([
          TaskType(
            id: 20,
            name: "Chore",
            icon: "wrench",
            capability_id: opt.None,
            tasks_count: 0,
          ),
        ]),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> element.to_document_string

  string.contains(html, ">None<") |> should.be_true
}

pub fn icon_picker_trigger_hides_slug_test() {
  let html =
    task_type_crud_dialog.view_icon_picker_trigger_for_test(
      En,
      "clipboard-document-list",
    )
    |> element.to_document_string

  string.contains(html, "clipboard-document-list") |> should.be_false
}

pub fn task_types_table_does_not_render_ids_test() {
  let model =
    base_model()
    |> update_admin(fn(admin) {
      AdminModel(
        ..admin,
        task_types: Loaded([
          TaskType(
            id: 1234,
            name: "Infra",
            icon: "bolt",
            capability_id: opt.None,
            tasks_count: 2,
          ),
        ]),
      )
    })

  let html =
    admin_view.view_task_types(model, opt.Some(sample_project()))
    |> element.to_document_string

  string.contains(html, ">1234<") |> should.be_false
}

pub fn task_type_create_dialog_shows_create_copy_and_optional_label_test() {
  let html =
    task_type_crud_dialog.view_create_dialog_for_test(Es)
    |> element.to_document_string

  string.contains(html, "Crear tipo") |> should.be_true
  string.contains(html, "form-group-optional") |> should.be_true
  string.contains(html, "Opcionales") |> should.be_true
}
