import gleam/option

import lustre/effect

import domain/api_error.{ApiError}
import domain/project.{type Project, Project}
import domain/project_role
import scrumbringer_client/client_state/admin/projects as admin_projects
import scrumbringer_client/client_state/types.{
  DialogClosed, DialogOpen, Error as OpError, Idle, InFlight,
  ProjectDialogCreate, ProjectDialogDelete, ProjectDialogEdit,
}
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/projects/update as projects_update

fn project(id: Int, name: String) -> Project {
  Project(
    id: id,
    name: name,
    my_role: project_role.Manager,
    created_at: "2026-01-01T00:00:00Z",
    members_count: 1,
  )
}

fn context() -> projects_update.Context(Nil) {
  projects_update.Context(
    on_project_created: fn(_result) { Nil },
    on_project_updated: fn(_result) { Nil },
    on_project_deleted: fn(_result) { Nil },
    name_required: "Name required",
  )
}

fn feedback_context() -> projects_update.FeedbackContext(Nil) {
  projects_update.FeedbackContext(
    project_created: "Project created",
    project_updated: "Saved",
    project_deleted: "Deleted",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_feedback_context() -> projects_update.ErrorFeedbackContext(Nil) {
  projects_update.ErrorFeedbackContext(
    not_permitted: "Not permitted",
    on_warning_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

pub fn create_dialog_opened_sets_empty_create_form_test() {
  let #(next, fx) =
    projects_update.handle_project_create_dialog_opened(
      admin_projects.default_model(),
    )

  let assert DialogOpen(form: ProjectDialogCreate(name: ""), operation: Idle) =
    next.projects_dialog
  let assert True = fx == effect.none()
}

pub fn create_submit_requires_name_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogCreate(name: "  "),
      operation: Idle,
    ))

  let #(next, fx) =
    projects_update.handle_project_create_submitted(model, context())

  let assert DialogOpen(
    form: ProjectDialogCreate(name: "  "),
    operation: OpError("Name required"),
  ) = next.projects_dialog
  let assert True = fx == effect.none()
}

pub fn create_submit_sets_in_flight_for_valid_name_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogCreate(name: " New project "),
      operation: Idle,
    ))

  let #(next, _fx) =
    projects_update.handle_project_create_submitted(model, context())

  let assert DialogOpen(
    form: ProjectDialogCreate(name: " New project "),
    operation: InFlight,
  ) = next.projects_dialog
}

pub fn edit_name_changed_preserves_project_id_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogEdit(id: 9, name: "Old"),
      operation: Idle,
    ))

  let #(next, fx) =
    projects_update.handle_project_edit_name_changed(model, "New")

  let assert DialogOpen(
    form: ProjectDialogEdit(id: 9, name: "New"),
    operation: Idle,
  ) = next.projects_dialog
  let assert True = fx == effect.none()
}

pub fn created_ok_closes_dialog_and_emits_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogCreate(name: "Project"),
      operation: InFlight,
    ))

  let #(next, fx) =
    projects_update.handle_project_created_ok(model, feedback_context())

  let assert True = fx != effect.none()
  let assert DialogClosed(operation: Idle) = next.projects_dialog
}

pub fn updated_ok_closes_dialog_and_emits_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogEdit(id: 9, name: "Project"),
      operation: InFlight,
    ))

  let #(next, fx) =
    projects_update.handle_project_updated_ok(model, feedback_context())

  let assert True = fx != effect.none()
  let assert DialogClosed(operation: Idle) = next.projects_dialog
}

pub fn update_error_sets_edit_dialog_error_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogEdit(id: 9, name: "Name"),
      operation: InFlight,
    ))

  let #(next, fx) =
    projects_update.handle_project_updated_error(
      model,
      ApiError(status: 403, code: "FORBIDDEN", message: "backend"),
      error_feedback_context(),
    )

  let assert DialogOpen(
    form: ProjectDialogEdit(id: 9, name: "Name"),
    operation: OpError("Not permitted"),
  ) = next.projects_dialog
  let assert True = fx == effect.none()
}

pub fn create_forbidden_error_sets_dialog_error_and_emits_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogCreate(name: "Project"),
      operation: InFlight,
    ))

  let #(next, fx) =
    projects_update.handle_project_created_error(
      model,
      ApiError(status: 403, code: "FORBIDDEN", message: "backend"),
      error_feedback_context(),
    )

  let assert DialogOpen(
    form: ProjectDialogCreate(name: "Project"),
    operation: OpError("Not permitted"),
  ) = next.projects_dialog
  let assert True = fx != effect.none()
}

pub fn delete_submit_sets_in_flight_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogDelete(id: 5, name: "Project"),
      operation: Idle,
    ))

  let #(next, _fx) =
    projects_update.handle_project_delete_submitted(model, context())

  let assert DialogOpen(
    form: ProjectDialogDelete(id: 5, name: "Project"),
    operation: InFlight,
  ) = next.projects_dialog
}

pub fn project_dialog_delete_id_reads_only_delete_dialogs_test() {
  let delete_dialog =
    DialogOpen(
      form: ProjectDialogDelete(id: 5, name: "Project"),
      operation: Idle,
    )
  let create_dialog =
    DialogOpen(form: ProjectDialogCreate(name: "Project"), operation: Idle)

  let assert option.Some(5) =
    projects_update.project_dialog_delete_id(delete_dialog)
  let assert option.None =
    projects_update.project_dialog_delete_id(create_dialog)
}

pub fn deleted_ok_closes_dialog_and_emits_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogDelete(id: 5, name: "Project"),
      operation: InFlight,
    ))

  let #(next, fx) =
    projects_update.handle_project_deleted_ok(model, feedback_context())

  let assert True = fx != effect.none()
  let assert DialogClosed(operation: Idle) = next.projects_dialog
}

pub fn deleted_error_returns_delete_dialog_to_idle_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogDelete(id: 5, name: "Project"),
      operation: InFlight,
    ))

  let #(next, fx) =
    projects_update.handle_project_deleted_error(
      model,
      ApiError(status: 403, code: "FORBIDDEN", message: "backend"),
      error_feedback_context(),
    )

  let assert DialogOpen(
    form: ProjectDialogDelete(id: 5, name: "Project"),
    operation: Idle,
  ) = next.projects_dialog
  let assert True = fx != effect.none()
}

pub fn deleted_generic_error_returns_to_idle_and_emits_error_feedback_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogDelete(id: 5, name: "Project"),
      operation: InFlight,
    ))

  let #(next, fx) =
    projects_update.handle_project_deleted_error(
      model,
      ApiError(status: 500, code: "ERR", message: "Boom"),
      error_feedback_context(),
    )

  let assert DialogOpen(
    form: ProjectDialogDelete(id: 5, name: "Project"),
    operation: Idle,
  ) = next.projects_dialog
  let assert True = fx != effect.none()
}

pub fn try_update_created_ok_returns_core_policy_test() {
  let created = project(7, "Project")
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogCreate(name: "Project"),
      operation: InFlight,
    ))

  let assert option.Some(projects_update.Update(
    next,
    fx,
    auth_policy,
    core_policy,
  )) =
    projects_update.try_update(
      model,
      admin_messages.ProjectCreated(Ok(created)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert DialogClosed(operation: Idle) = next.projects_dialog
  let assert True = fx != effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.CoreProjectCreated(policy_project) = core_policy
  let assert 7 = policy_project.id
}

pub fn try_update_deleted_ok_preserves_delete_id_in_core_policy_test() {
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogDelete(id: 5, name: "Project"),
      operation: InFlight,
    ))

  let assert option.Some(projects_update.Update(
    next,
    fx,
    auth_policy,
    core_policy,
  )) =
    projects_update.try_update(
      model,
      admin_messages.ProjectDeleted(Ok(Nil)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert DialogClosed(operation: Idle) = next.projects_dialog
  let assert True = fx != effect.none()
  let assert projects_update.NoAuthCheck = auth_policy
  let assert projects_update.CoreProjectDeleted(option.Some(5)) = core_policy
}

pub fn try_update_error_requests_auth_check_test() {
  let err = ApiError(status: 500, code: "ERR", message: "Backend failed")
  let model =
    admin_projects.Model(projects_dialog: DialogOpen(
      form: ProjectDialogEdit(id: 9, name: "Project"),
      operation: InFlight,
    ))

  let assert option.Some(projects_update.Update(
    next,
    fx,
    auth_policy,
    core_policy,
  )) =
    projects_update.try_update(
      model,
      admin_messages.ProjectUpdated(Error(err)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert DialogOpen(
    form: ProjectDialogEdit(id: 9, name: "Project"),
    operation: OpError("Backend failed"),
  ) = next.projects_dialog
  let assert True = fx == effect.none()
  let assert projects_update.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
  let assert projects_update.NoCoreChange = core_policy
}
