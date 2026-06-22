import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/project.{type Project, Project}
import domain/project_role
import domain/remote.{Loaded}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/projects as admin_projects
import scrumbringer_client/client_state/types.{DialogOpen, InFlight}
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/projects_route
import scrumbringer_client/permissions

fn base_model() -> client_state.Model {
  client_state.update_core(client_state.default_model(), fn(core) {
    client_state.CoreModel(
      ..core,
      page: client_state.Admin,
      active_section: permissions.Team,
    )
  })
}

fn project(id: Int, name: String) -> Project {
  Project(
    id: id,
    name: name,
    my_role: project_role.Manager,
    created_at: "2026-01-01T00:00:00Z",
    members_count: 1,
    card_depth_names: [],
  )
}

pub fn try_update_routes_project_created_and_syncs_core_test() {
  let created = project(7, "New")

  let assert opt.Some(#(next, fx)) =
    projects_route.try_update(
      base_model(),
      admin_messages.ProjectCreated(Ok(created)),
    )

  let assert opt.Some(7) = next.core.selected_project_id
  let assert Loaded([stored]) = next.core.projects
  let assert 7 = stored.id
  let assert "New" = stored.name
  let assert True = fx != effect.none()
}

pub fn try_update_routes_project_deleted_and_syncs_core_test() {
  let existing = project(3, "Old")
  let model =
    base_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(
        ..core,
        projects: Loaded([existing]),
        selected_project_id: opt.Some(3),
      )
    })
    |> client_state.update_admin(fn(admin) {
      let projects =
        admin_projects.Model(projects_dialog: DialogOpen(
          form: admin_projects.ProjectDialogDelete(id: 3, name: "Old"),
          operation: InFlight,
        ))
      admin_state.AdminModel(..admin, projects: projects)
    })

  let assert opt.Some(#(next, fx)) =
    projects_route.try_update(model, admin_messages.ProjectDeleted(Ok(Nil)))

  let assert opt.None = next.core.selected_project_id
  let assert Loaded([]) = next.core.projects
  let assert True = fx != effect.none()
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")
  let model =
    base_model()
    |> client_state.update_admin(fn(admin) {
      let projects =
        admin_projects.Model(projects_dialog: DialogOpen(
          form: admin_projects.ProjectDialogDelete(id: 3, name: "Old"),
          operation: InFlight,
        ))
      admin_state.AdminModel(..admin, projects: projects)
    })

  let assert opt.Some(#(next, fx)) =
    projects_route.try_update(model, admin_messages.ProjectDeleted(Error(err)))

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_project_messages_test() {
  let assert opt.None =
    projects_route.try_update(
      base_model(),
      admin_messages.MemberAddDialogOpened,
    )
}
