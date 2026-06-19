import gleam/int
import gleam/string
import lustre/element

import domain/project.{type Project, Project}
import domain/project_role
import domain/remote
import scrumbringer_client/client_state/admin/projects as projects_state
import scrumbringer_client/client_state/types.{DialogOpen, InFlight}
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn project() -> Project {
  Project(
    id: 7,
    name: "Project Alpha",
    my_role: project_role.Manager,
    created_at: "2026-01-01T10:00:00Z",
    members_count: 3,
    card_depth_names: [],
  )
}

fn config(
  projects: remote.Remote(List(Project)),
) -> projects_view.Config(String) {
  projects_view.Config(
    locale: locale.En,
    projects: projects,
    project_dialog: projects_state.default_model(),
    on_create_dialog_opened: "create-open",
    on_create_dialog_closed: "create-close",
    on_create_submitted: "create-submit",
    on_create_name_changed: fn(value) { "create-name:" <> value },
    on_edit_dialog_opened: fn(id, name) {
      "edit-open:" <> int.to_string(id) <> ":" <> name
    },
    on_edit_dialog_closed: "edit-close",
    on_edit_submitted: "edit-submit",
    on_edit_name_changed: fn(value) { "edit-name:" <> value },
    on_delete_confirm_opened: fn(id, name) {
      "delete-open:" <> int.to_string(id) <> ":" <> name
    },
    on_delete_confirm_closed: "delete-close",
    on_delete_submitted: "delete-submit",
  )
}

pub fn projects_view_loaded_projects_uses_config_data_test() {
  let html =
    projects_view.view_projects(config(remote.Loaded([project()])))
    |> element.to_document_string

  assert_contains(html, "Projects")
  assert_contains(html, "Project Alpha")
  assert_contains(html, "Members")
  assert_contains(html, "3")
  assert_contains(html, "manager")
}

pub fn projects_view_delete_dialog_uses_shared_danger_button_test() {
  let dialog =
    projects_state.Model(projects_dialog: DialogOpen(
      form: projects_state.ProjectDialogDelete(id: 7, name: "Project Alpha"),
      operation: InFlight,
    ))

  let html =
    projects_view.view_project_dialogs(
      projects_view.Config(
        ..config(remote.Loaded([project()])),
        project_dialog: dialog,
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Delete project")
  assert_contains(html, "Deleting")
  assert_contains(html, "btn-danger")
  assert_contains(html, "btn-entity-action")
  assert_not_contains(html, "class=\"btn-danger\"")
}
