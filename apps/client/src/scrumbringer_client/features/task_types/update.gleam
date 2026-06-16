//// Task types feature update handlers.
////
//// ## Mission
////
//// Handles task type creation and listing flows.
////
//// ## Responsibilities
////
//// - Task type create form state and submission
//// - Icon preview handling
//// - Capability assignment for task types
////
//// ## Non-responsibilities
////
//// - API calls (see `api/tasks/task_types.gleam`)
//// - Task creation (see `features/tasks/create_update.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches task type messages to handlers here
//// - **api/tasks/task_types.gleam**: Provides API effects for task type operations

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/tasks/task_types as task_types_api

// Domain types
import domain/api_error.{type ApiError, type ApiResult}
import domain/remote.{Failed, Loaded}
import domain/task_type.{type TaskType}
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_task_type_created: fn(ApiResult(TaskType)) -> parent_msg,
    select_project_first: String,
    name_and_icon_required: String,
  )
}

type Success {
  TaskTypeCreated
  TaskTypeUpdated
  TaskTypeDeleted
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    task_type_created: String,
    task_type_updated: String,
    task_type_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorFeedbackContext(parent_msg) {
  ErrorFeedbackContext(
    not_permitted: String,
    on_warning_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type RefreshPolicy {
  NoRefresh
  RefreshSection
}

pub type Update(parent_msg) {
  Update(admin_task_types.Model, Effect(parent_msg), AuthPolicy, RefreshPolicy)
}

pub fn try_update(
  model: admin_task_types.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
  error_feedback: ErrorFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.TaskTypesFetched(Ok(task_types)) ->
      handle_task_types_fetched_ok(model, task_types)
      |> without_auth_check

    admin_messages.TaskTypesFetched(Error(err)) ->
      handle_task_types_fetched_error(model, err)
      |> with_auth_check(err)

    admin_messages.TaskTypeCreateDialogOpened ->
      handle_task_type_dialog_opened(model)
      |> without_auth_check

    admin_messages.TaskTypeCreateDialogClosed ->
      handle_task_type_dialog_closed(model)
      |> without_auth_check

    admin_messages.TaskTypeCreateNameChanged(name) ->
      handle_task_type_create_name_changed(model, name)
      |> without_auth_check

    admin_messages.TaskTypeCreateIconChanged(icon) ->
      handle_task_type_create_icon_changed(model, icon)
      |> without_auth_check

    admin_messages.TaskTypeCreateIconSearchChanged(search) ->
      handle_task_type_create_icon_search_changed(model, search)
      |> without_auth_check

    admin_messages.TaskTypeCreateIconCategoryChanged(category) ->
      handle_task_type_create_icon_category_changed(model, category)
      |> without_auth_check

    admin_messages.TaskTypeIconLoaded ->
      handle_task_type_icon_loaded(model)
      |> without_auth_check

    admin_messages.TaskTypeIconErrored ->
      handle_task_type_icon_errored(model)
      |> without_auth_check

    admin_messages.TaskTypeCreateCapabilityChanged(value) ->
      handle_task_type_create_capability_changed(model, value)
      |> without_auth_check

    admin_messages.TaskTypeCreateSubmitted ->
      handle_task_type_create_submitted(model, context)
      |> without_auth_check

    admin_messages.TaskTypeCreated(Ok(_)) ->
      handle_task_type_created_ok(model, feedback)
      |> with_refresh(RefreshSection)

    admin_messages.TaskTypeCreated(Error(err)) ->
      handle_task_type_created_error(
        model,
        permission_error_message(err, error_feedback),
      )
      |> with_auth_check_and_effect(
        err,
        permission_warning_effect(err, error_feedback),
      )

    admin_messages.OpenTaskTypeDialog(mode) ->
      handle_open_task_type_dialog(model, mode)
      |> without_auth_check

    admin_messages.CloseTaskTypeDialog ->
      handle_close_task_type_dialog(model)
      |> without_auth_check

    admin_messages.TaskTypeCrudCreated(task_type) ->
      handle_task_type_crud_created(model, task_type, feedback)
      |> with_refresh(RefreshSection)

    admin_messages.TaskTypeCrudUpdated(task_type) ->
      handle_task_type_crud_updated(model, task_type, feedback)
      |> without_auth_check

    admin_messages.TaskTypeCrudDeleted(type_id) ->
      handle_task_type_crud_deleted(model, type_id, feedback)
      |> without_auth_check

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(admin_task_types.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck, NoRefresh)
}

fn with_auth_check(
  result: #(admin_task_types.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err), NoRefresh)
}

fn with_auth_check_and_effect(
  result: #(admin_task_types.Model, Effect(parent_msg)),
  err: ApiError,
  extra_fx: Effect(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(
    model,
    effect.batch([fx, extra_fx]),
    CheckAuth(err),
    NoRefresh,
  ))
}

fn with_refresh(
  result: #(admin_task_types.Model, Effect(parent_msg)),
  refresh_policy: RefreshPolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck, refresh_policy)
}

fn with_policy(
  result: #(admin_task_types.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
  refresh_policy: RefreshPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy, refresh_policy))
}

fn permission_error_message(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> String {
  case err.status {
    403 -> feedback.not_permitted
    _ -> err.message
  }
}

fn permission_warning_effect(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(feedback.not_permitted)
    _ -> effect.none()
  }
}

// =============================================================================
// Task Types Fetch Handlers
// =============================================================================

/// Handle task types fetch success.
fn handle_task_types_fetched_ok(
  model: admin_task_types.Model,
  task_types: List(TaskType),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(..model, task_types: Loaded(task_types)),
    effect.none(),
  )
}

/// Handle task types fetch error.
fn handle_task_types_fetched_error(
  model: admin_task_types.Model,
  err: ApiError,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(admin_task_types.Model(..model, task_types: Failed(err)), effect.none())
}

// =============================================================================
// Task Type Dialog Handlers
// =============================================================================

/// Handle task type create dialog open.
fn handle_task_type_dialog_opened(
  model: admin_task_types.Model,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(
      ..model,
      task_types_dialog_mode: opt.Some(admin_task_types.TaskTypeDialogCreate),
    ),
    effect.none(),
  )
}

/// Handle task type create dialog close.
fn handle_task_type_dialog_closed(
  model: admin_task_types.Model,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(
      ..model,
      task_types_dialog_mode: opt.None,
      task_types_create_name: "",
      task_types_create_icon: "",
      task_types_create_icon_search: "",
      task_types_create_icon_category: "all",
      task_types_create_in_flight: False,
      task_types_create_capability_id: opt.None,
      task_types_create_error: opt.None,
      task_types_icon_preview: admin_task_types.IconIdle,
    ),
    effect.none(),
  )
}

// =============================================================================
// Task Type Create Handlers
// =============================================================================

/// Handle task type create name input change.
fn handle_task_type_create_name_changed(
  model: admin_task_types.Model,
  name: String,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(..model, task_types_create_name: name),
    effect.none(),
  )
}

/// Handle task type create icon input change.
/// With the catalog approach, icons are validated instantly against the curated catalog.
fn handle_task_type_create_icon_changed(
  model: admin_task_types.Model,
  icon: String,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  // Import icon_catalog for validation
  let preview_state = case icon == "" {
    True -> admin_task_types.IconIdle
    False -> admin_task_types.IconOk
    // All icons from picker are valid catalog icons
  }
  #(
    admin_task_types.Model(
      ..model,
      task_types_create_icon: icon,
      task_types_icon_preview: preview_state,
    ),
    effect.none(),
  )
}

/// Handle task type icon loaded.
fn handle_task_type_icon_loaded(
  model: admin_task_types.Model,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(
      ..model,
      task_types_icon_preview: admin_task_types.IconOk,
    ),
    effect.none(),
  )
}

/// Handle task type icon error.
fn handle_task_type_icon_errored(
  model: admin_task_types.Model,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(
      ..model,
      task_types_icon_preview: admin_task_types.IconError,
    ),
    effect.none(),
  )
}

/// Handle icon picker search input change.
fn handle_task_type_create_icon_search_changed(
  model: admin_task_types.Model,
  search: String,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(..model, task_types_create_icon_search: search),
    effect.none(),
  )
}

/// Handle icon picker category tab change.
fn handle_task_type_create_icon_category_changed(
  model: admin_task_types.Model,
  category: String,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(..model, task_types_create_icon_category: category),
    effect.none(),
  )
}

/// Handle task type create capability dropdown change.
fn handle_task_type_create_capability_changed(
  model: admin_task_types.Model,
  value: String,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  case string.trim(value) == "" {
    True -> #(
      admin_task_types.Model(..model, task_types_create_capability_id: opt.None),
      effect.none(),
    )
    False -> #(
      admin_task_types.Model(
        ..model,
        task_types_create_capability_id: opt.Some(value),
      ),
      effect.none(),
    )
  }
}

/// Handle task type create form submission.
fn handle_task_type_create_submitted(
  model: admin_task_types.Model,
  context: Context(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  case model.task_types_create_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_submit_task_type(model, context)
  }
}

/// Validate inputs and submit task type creation.
fn validate_and_submit_task_type(
  model: admin_task_types.Model,
  context: Context(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  case context.selected_project_id {
    opt.None -> set_task_type_error(model, context.select_project_first)
    opt.Some(project_id) ->
      validate_task_type_fields(model, project_id, context)
  }
}

/// Validate name, icon, and icon preview state.
fn validate_task_type_fields(
  model: admin_task_types.Model,
  project_id: Int,
  context: Context(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  let name = string.trim(model.task_types_create_name)
  let icon = string.trim(model.task_types_create_icon)

  case name == "" || icon == "" {
    True -> set_task_type_error(model, context.name_and_icon_required)
    False -> validate_icon_preview(model, project_id, name, icon, context)
  }
}

/// Check icon preview status before submission.
/// With catalog validation, we just check if the icon exists in the catalog.
fn validate_icon_preview(
  model: admin_task_types.Model,
  project_id: Int,
  name: String,
  icon: String,
  context: Context(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  // All icons selected from the picker are valid catalog icons
  // Submit directly without checking preview state
  submit_task_type(model, project_id, name, icon, context)
}

/// Set a validation error on the task type create form.
fn set_task_type_error(
  model: admin_task_types.Model,
  message: String,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(..model, task_types_create_error: opt.Some(message)),
    effect.none(),
  )
}

fn submit_task_type(
  model: admin_task_types.Model,
  project_id: Int,
  name: String,
  icon: String,
  context: Context(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  let capability_id = case model.task_types_create_capability_id {
    opt.None -> opt.None
    opt.Some(id_str) ->
      case int.parse(id_str) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }
  }

  let model =
    admin_task_types.Model(
      ..model,
      task_types_create_in_flight: True,
      task_types_create_error: opt.None,
    )

  #(
    model,
    task_types_api.create_task_type(
      project_id,
      name,
      icon,
      capability_id,
      context.on_task_type_created,
    ),
  )
}

/// Handle task type created success.
fn handle_task_type_created_ok(
  model: admin_task_types.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(
      ..model,
      task_types_dialog_mode: opt.None,
      task_types_create_in_flight: False,
      task_types_create_name: "",
      task_types_create_icon: "",
      task_types_create_icon_search: "",
      task_types_create_icon_category: "all",
      task_types_create_capability_id: opt.None,
      task_types_create_error: opt.None,
      task_types_icon_preview: admin_task_types.IconIdle,
    ),
    success_effect(TaskTypeCreated, feedback),
  )
}

/// Handle task type created error.
fn handle_task_type_created_error(
  model: admin_task_types.Model,
  message: String,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(
      ..model,
      task_types_create_in_flight: False,
      task_types_create_error: opt.Some(message),
    ),
    effect.none(),
  )
}

// =============================================================================
// Task Type Dialog Mode Handlers (component pattern)
// =============================================================================

/// Handle task type dialog open (using new component pattern).
fn handle_open_task_type_dialog(
  model: admin_task_types.Model,
  mode: admin_task_types.TaskTypeDialogMode,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(..model, task_types_dialog_mode: opt.Some(mode)),
    effect.none(),
  )
}

/// Handle task type dialog close (using new component pattern).
fn handle_close_task_type_dialog(
  model: admin_task_types.Model,
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(..model, task_types_dialog_mode: opt.None),
    effect.none(),
  )
}

/// Handle task type created from component event.
fn handle_task_type_crud_created(
  model: admin_task_types.Model,
  _task_type: TaskType,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  #(
    admin_task_types.Model(..model, task_types_dialog_mode: opt.None),
    success_effect(TaskTypeCreated, feedback),
  )
}

/// Handle task type updated from component event.
fn handle_task_type_crud_updated(
  model: admin_task_types.Model,
  task_type: TaskType,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  // Update task type in the list
  let updated_list = case model.task_types {
    Loaded(task_types) ->
      Loaded(
        task_types
        |> list.map(fn(tt) {
          case tt.id == task_type.id {
            True -> task_type
            False -> tt
          }
        }),
      )
    other -> other
  }
  #(
    admin_task_types.Model(
      ..model,
      task_types: updated_list,
      task_types_dialog_mode: opt.None,
    ),
    success_effect(TaskTypeUpdated, feedback),
  )
}

/// Handle task type deleted from component event.
fn handle_task_type_crud_deleted(
  model: admin_task_types.Model,
  type_id: Int,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_task_types.Model, Effect(parent_msg)) {
  // Remove task type from the list
  let updated_list = case model.task_types {
    Loaded(task_types) ->
      Loaded(list.filter(task_types, fn(tt) { tt.id != type_id }))
    other -> other
  }
  #(
    admin_task_types.Model(
      ..model,
      task_types: updated_list,
      task_types_dialog_mode: opt.None,
    ),
    success_effect(TaskTypeDeleted, feedback),
  )
}

fn success_effect(
  success: Success,
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  context.on_success_toast(success_message(success, context))
}

fn success_message(success: Success, context: FeedbackContext(parent_msg)) {
  case success {
    TaskTypeCreated -> context.task_type_created
    TaskTypeUpdated -> context.task_type_updated
    TaskTypeDeleted -> context.task_type_deleted
  }
}
