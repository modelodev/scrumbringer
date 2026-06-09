//// Projects feature update handlers.
////
//// ## Mission
////
//// Handles project CRUD dialog state.
////
//// ## Responsibilities
////
//// - Project create/edit/delete form state and submission
//// - Dialog operation states and validation
////
//// ## Non-responsibilities
////
//// - Root model assembly for project CRUD dialogs (see `features/admin/update.gleam`)
//// - Navigation (see `client_update.gleam`)
////
//// ## Relations
////
//// - **features/admin/update.gleam**: Assembles root state and toasts
//// - **api/projects.gleam**: Provides API effects for project operations

import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/projects as api_projects

// Domain types
import domain/api_error.{type ApiError, type ApiResult}
import domain/project.{type Project}
import scrumbringer_client/client_state/admin/projects as admin_projects
import scrumbringer_client/client_state/types.{
  type DialogState, type OperationState, type ProjectDialogForm, DialogClosed,
  DialogOpen, Error as OpError, Idle, InFlight, ProjectDialogCreate,
  ProjectDialogDelete, ProjectDialogEdit,
}
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(
    on_project_created: fn(ApiResult(Project)) -> parent_msg,
    on_project_updated: fn(ApiResult(Project)) -> parent_msg,
    on_project_deleted: fn(ApiResult(Nil)) -> parent_msg,
    name_required: String,
  )
}

pub type Success {
  ProjectCreated
  ProjectUpdated
  ProjectDeleted
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    project_created: String,
    project_updated: String,
    project_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorFeedbackContext(parent_msg) {
  ErrorFeedbackContext(
    not_permitted: String,
    on_warning_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type CorePolicy {
  NoCoreChange
  CoreProjectCreated(Project)
  CoreProjectUpdated(Project)
  CoreProjectDeleted(opt.Option(Int))
}

pub type Update(parent_msg) {
  Update(admin_projects.Model, Effect(parent_msg), AuthPolicy, CorePolicy)
}

pub fn try_update(
  model: admin_projects.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
  error_feedback: ErrorFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.ProjectCreateDialogOpened ->
      handle_project_create_dialog_opened(model)
      |> without_policies

    admin_messages.ProjectCreateDialogClosed ->
      handle_project_create_dialog_closed(model)
      |> without_policies

    admin_messages.ProjectCreateNameChanged(name) ->
      handle_project_create_name_changed(model, name)
      |> without_policies

    admin_messages.ProjectCreateSubmitted ->
      handle_project_create_submitted(model, context)
      |> without_policies

    admin_messages.ProjectCreated(Ok(project)) ->
      handle_project_created_ok(model, feedback)
      |> with_core_policy(CoreProjectCreated(project))

    admin_messages.ProjectCreated(Error(err)) ->
      handle_project_created_error(model, err, error_feedback)
      |> with_auth_policy(CheckAuth(err))

    admin_messages.ProjectEditDialogOpened(project_id, project_name) ->
      handle_project_edit_dialog_opened(model, project_id, project_name)
      |> without_policies

    admin_messages.ProjectEditDialogClosed ->
      handle_project_edit_dialog_closed(model)
      |> without_policies

    admin_messages.ProjectEditNameChanged(name) ->
      handle_project_edit_name_changed(model, name)
      |> without_policies

    admin_messages.ProjectEditSubmitted ->
      handle_project_edit_submitted(model, context)
      |> without_policies

    admin_messages.ProjectUpdated(Ok(project)) ->
      handle_project_updated_ok(model, feedback)
      |> with_core_policy(CoreProjectUpdated(project))

    admin_messages.ProjectUpdated(Error(err)) ->
      handle_project_updated_error(model, err, error_feedback)
      |> with_auth_policy(CheckAuth(err))

    admin_messages.ProjectDeleteConfirmOpened(project_id, project_name) ->
      handle_project_delete_confirm_opened(model, project_id, project_name)
      |> without_policies

    admin_messages.ProjectDeleteConfirmClosed ->
      handle_project_delete_confirm_closed(model)
      |> without_policies

    admin_messages.ProjectDeleteSubmitted ->
      handle_project_delete_submitted(model, context)
      |> without_policies

    admin_messages.ProjectDeleted(Ok(_)) ->
      handle_project_deleted_ok(model, feedback)
      |> with_core_policy(
        CoreProjectDeleted(project_dialog_delete_id(model.projects_dialog)),
      )

    admin_messages.ProjectDeleted(Error(err)) ->
      handle_project_deleted_error(model, err, error_feedback)
      |> with_auth_policy(CheckAuth(err))

    _ -> opt.None
  }
}

fn without_policies(
  result: #(admin_projects.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policies(result, NoAuthCheck, NoCoreChange)
}

fn with_auth_policy(
  result: #(admin_projects.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policies(result, auth_policy, NoCoreChange)
}

fn with_core_policy(
  result: #(admin_projects.Model, Effect(parent_msg)),
  core_policy: CorePolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policies(result, NoAuthCheck, core_policy)
}

fn with_policies(
  result: #(admin_projects.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
  core_policy: CorePolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy, core_policy))
}

// =============================================================================
// Project Create Handlers
// =============================================================================

/// Handle project create dialog opened.
pub fn handle_project_create_dialog_opened(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(
      model,
      DialogOpen(form: ProjectDialogCreate(name: ""), operation: Idle),
    ),
    effect.none(),
  )
}

/// Handle project create dialog closed.
pub fn handle_project_create_dialog_closed(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(set_projects_dialog(model, DialogClosed(operation: Idle)), effect.none())
}

/// Handle project create name input change.
pub fn handle_project_create_name_changed(
  model: admin_projects.Model,
  name: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(form: ProjectDialogCreate(name: _), operation: op) ->
      DialogOpen(form: ProjectDialogCreate(name: name), operation: op)
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

/// Handle project create form submission.
pub fn handle_project_create_submitted(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(form: ProjectDialogCreate(name: name), operation: op) ->
      submit_project_create(model, name, operation_in_flight(op), context)
    _ -> #(model, effect.none())
  }
}

fn submit_project_create(
  model: admin_projects.Model,
  name: String,
  in_flight: Bool,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case in_flight {
    True -> #(model, effect.none())
    False -> {
      let trimmed = string.trim(name)
      case trimmed == "" {
        True -> #(
          set_projects_dialog(
            model,
            update_project_dialog_error(
              model.projects_dialog,
              context.name_required,
            ),
          ),
          effect.none(),
        )
        False -> submit_project_create_valid(model, trimmed, context)
      }
    }
  }
}

fn submit_project_create_valid(
  model: admin_projects.Model,
  name: String,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let model =
    set_projects_dialog(
      model,
      update_project_dialog_in_flight(model.projects_dialog),
    )
  #(model, api_projects.create_project(name, context.on_project_created))
}

/// Handle project created success.
pub fn handle_project_created_ok(
  model: admin_projects.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(model, DialogClosed(operation: Idle)),
    success_effect(ProjectCreated, feedback),
  )
}

/// Handle project created error.
pub fn handle_project_created_error(
  model: admin_projects.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)

  case model.projects_dialog {
    DialogOpen(form: ProjectDialogCreate(name: _), ..) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(model.projects_dialog, message),
      ),
      forbidden_warning_effect(err, message, feedback),
    )
    _ -> #(model, effect.none())
  }
}

// =============================================================================
// Project Edit Handlers (Story 4.8 AC39)
// =============================================================================

/// Handle project edit dialog opened.
pub fn handle_project_edit_dialog_opened(
  model: admin_projects.Model,
  project_id: Int,
  project_name: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(
      model,
      DialogOpen(
        form: ProjectDialogEdit(id: project_id, name: project_name),
        operation: Idle,
      ),
    ),
    effect.none(),
  )
}

/// Handle project edit dialog closed.
pub fn handle_project_edit_dialog_closed(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(set_projects_dialog(model, DialogClosed(operation: Idle)), effect.none())
}

/// Handle project edit name input change.
pub fn handle_project_edit_name_changed(
  model: admin_projects.Model,
  name: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(form: ProjectDialogEdit(id: id, name: _), operation: op) ->
      DialogOpen(form: ProjectDialogEdit(id: id, name: name), operation: op)
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

/// Handle project edit form submission.
pub fn handle_project_edit_submitted(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(
      form: ProjectDialogEdit(id: project_id, name: name),
      operation: op,
    ) ->
      submit_project_edit(
        model,
        project_id,
        name,
        operation_in_flight(op),
        context,
      )
    _ -> #(model, effect.none())
  }
}

fn submit_project_edit(
  model: admin_projects.Model,
  project_id: Int,
  name: String,
  in_flight: Bool,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case in_flight {
    True -> #(model, effect.none())
    False -> {
      let trimmed = string.trim(name)
      case trimmed == "" {
        True -> #(
          set_projects_dialog(
            model,
            update_project_dialog_error(
              model.projects_dialog,
              context.name_required,
            ),
          ),
          effect.none(),
        )
        False -> submit_project_edit_valid(model, project_id, trimmed, context)
      }
    }
  }
}

fn submit_project_edit_valid(
  model: admin_projects.Model,
  project_id: Int,
  name: String,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let model =
    set_projects_dialog(
      model,
      update_project_dialog_in_flight(model.projects_dialog),
    )
  #(
    model,
    api_projects.update_project(project_id, name, context.on_project_updated),
  )
}

/// Handle project updated success.
pub fn handle_project_updated_ok(
  model: admin_projects.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(model, DialogClosed(operation: Idle)),
    success_effect(ProjectUpdated, feedback),
  )
}

/// Handle project updated error.
pub fn handle_project_updated_error(
  model: admin_projects.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)

  case model.projects_dialog {
    DialogOpen(form: ProjectDialogEdit(id: _, name: _), ..) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(model.projects_dialog, message),
      ),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

// =============================================================================
// Project Delete Handlers (Story 4.8 AC39)
// =============================================================================

/// Handle project delete confirm opened.
pub fn handle_project_delete_confirm_opened(
  model: admin_projects.Model,
  project_id: Int,
  project_name: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(
      model,
      DialogOpen(
        form: ProjectDialogDelete(id: project_id, name: project_name),
        operation: Idle,
      ),
    ),
    effect.none(),
  )
}

/// Handle project delete confirm closed.
pub fn handle_project_delete_confirm_closed(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(set_projects_dialog(model, DialogClosed(operation: Idle)), effect.none())
}

/// Handle project delete submission.
pub fn handle_project_delete_submitted(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(
      form: ProjectDialogDelete(id: project_id, name: _name),
      operation: op,
    ) ->
      case operation_in_flight(op) {
        True -> #(model, effect.none())
        False -> {
          let model =
            set_projects_dialog(
              model,
              update_project_dialog_in_flight(model.projects_dialog),
            )
          #(
            model,
            api_projects.delete_project(project_id, context.on_project_deleted),
          )
        }
      }
    _ -> #(model, effect.none())
  }
}

/// Handle project deleted success.
pub fn handle_project_deleted_ok(
  model: admin_projects.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(model, DialogClosed(operation: Idle)),
    success_effect(ProjectDeleted, feedback),
  )
}

/// Handle project deleted error.
pub fn handle_project_deleted_error(
  model: admin_projects.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)

  case model.projects_dialog {
    DialogOpen(form: ProjectDialogDelete(id: _, name: _), ..) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_idle(model.projects_dialog),
      ),
      delete_error_effect(err, message, feedback),
    )
    _ -> #(model, effect.none())
  }
}

// =============================================================================
// Dialog Helpers
// =============================================================================

fn operation_in_flight(operation: OperationState) -> Bool {
  case operation {
    InFlight -> True
    _ -> False
  }
}

fn set_projects_dialog(
  _model: admin_projects.Model,
  dialog: DialogState(ProjectDialogForm),
) -> admin_projects.Model {
  admin_projects.Model(projects_dialog: dialog)
}

fn update_project_dialog_error(
  dialog: DialogState(ProjectDialogForm),
  message: String,
) -> DialogState(ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) ->
      DialogOpen(form: form, operation: OpError(message))
    DialogClosed(..) -> DialogClosed(operation: OpError(message))
  }
}

fn update_project_dialog_in_flight(
  dialog: DialogState(ProjectDialogForm),
) -> DialogState(ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) -> DialogOpen(form: form, operation: InFlight)
    DialogClosed(..) -> DialogClosed(operation: InFlight)
  }
}

fn update_project_dialog_idle(
  dialog: DialogState(ProjectDialogForm),
) -> DialogState(ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) -> DialogOpen(form: form, operation: Idle)
    DialogClosed(..) -> DialogClosed(operation: Idle)
  }
}

pub fn success_effect(
  success: Success,
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  context.on_success_toast(success_message(success, context))
}

pub fn error_message(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> String {
  case err.status {
    403 -> feedback.not_permitted
    _ -> err.message
  }
}

fn forbidden_warning_effect(
  err: ApiError,
  message: String,
  feedback: ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(message)
    _ -> effect.none()
  }
}

fn delete_error_effect(
  err: ApiError,
  message: String,
  feedback: ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(message)
    _ -> feedback.on_error_toast(message)
  }
}

fn success_message(success: Success, context: FeedbackContext(parent_msg)) {
  case success {
    ProjectCreated -> context.project_created
    ProjectUpdated -> context.project_updated
    ProjectDeleted -> context.project_deleted
  }
}

pub fn project_dialog_delete_id(
  dialog: DialogState(ProjectDialogForm),
) -> opt.Option(Int) {
  case dialog {
    DialogOpen(form: ProjectDialogDelete(id: id, name: _), ..) -> opt.Some(id)
    _ -> opt.None
  }
}
