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
//// - API calls (see `api/tasks.gleam`)
//// - Task creation (see `features/tasks/update.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches task type messages to handlers here
//// - **api/tasks.gleam**: Provides API effects for task type operations

import gleam/int
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/tasks as api_tasks
// Domain types
import domain/api_error.{type ApiError}
import domain/task_type.{type TaskType}
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, IconError, IconIdle, IconLoading, IconOk, Loaded,
  Model, TaskTypeCreated,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Task Types Fetch Handlers
// =============================================================================

/// Handle task types fetch success.
pub fn handle_task_types_fetched_ok(
  model: Model,
  task_types: List(TaskType),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, task_types: Loaded(task_types)), effect.none())
}

/// Handle task types fetch error.
pub fn handle_task_types_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> update_helpers.reset_to_login(model)
    False -> #(Model(..model, task_types: Failed(err)), effect.none())
  }
}

// =============================================================================
// Task Type Create Handlers
// =============================================================================

/// Handle task type create name input change.
pub fn handle_task_type_create_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, task_types_create_name: name), effect.none())
}

/// Handle task type create icon input change.
pub fn handle_task_type_create_icon_changed(
  model: Model,
  icon: String,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      task_types_create_icon: icon,
      task_types_icon_preview: IconLoading,
    ),
    effect.none(),
  )
}

/// Handle task type icon loaded.
pub fn handle_task_type_icon_loaded(model: Model) -> #(Model, Effect(Msg)) {
  #(Model(..model, task_types_icon_preview: IconOk), effect.none())
}

/// Handle task type icon error.
pub fn handle_task_type_icon_errored(model: Model) -> #(Model, Effect(Msg)) {
  #(Model(..model, task_types_icon_preview: IconError), effect.none())
}

/// Handle task type create capability dropdown change.
pub fn handle_task_type_create_capability_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  case string.trim(value) == "" {
    True -> #(
      Model(..model, task_types_create_capability_id: opt.None),
      effect.none(),
    )
    False -> #(
      Model(..model, task_types_create_capability_id: opt.Some(value)),
      effect.none(),
    )
  }
}

/// Handle task type create form submission.
pub fn handle_task_type_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.task_types_create_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_submit_task_type(model)
  }
}

/// Validate inputs and submit task type creation.
fn validate_and_submit_task_type(model: Model) -> #(Model, Effect(Msg)) {
  case model.selected_project_id {
    opt.None -> set_task_type_error(model, i18n_text.SelectProjectFirst)
    opt.Some(project_id) -> validate_task_type_fields(model, project_id)
  }
}

/// Validate name, icon, and icon preview state.
fn validate_task_type_fields(
  model: Model,
  project_id: Int,
) -> #(Model, Effect(Msg)) {
  let name = string.trim(model.task_types_create_name)
  let icon = string.trim(model.task_types_create_icon)

  case name == "" || icon == "" {
    True -> set_task_type_error(model, i18n_text.NameAndIconRequired)
    False -> validate_icon_preview(model, project_id, name, icon)
  }
}

/// Check icon preview status before submission.
fn validate_icon_preview(
  model: Model,
  project_id: Int,
  name: String,
  icon: String,
) -> #(Model, Effect(Msg)) {
  case model.task_types_icon_preview {
    IconError -> set_task_type_error(model, i18n_text.UnknownIcon)
    IconLoading | IconIdle -> set_task_type_error(model, i18n_text.WaitForIconPreview)
    IconOk -> submit_task_type(model, project_id, name, icon)
  }
}

/// Set a validation error on the task type create form.
fn set_task_type_error(
  model: Model,
  message: i18n_text.Text,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      task_types_create_error: opt.Some(update_helpers.i18n_t(model, message)),
    ),
    effect.none(),
  )
}

fn submit_task_type(
  model: Model,
  project_id: Int,
  name: String,
  icon: String,
) -> #(Model, Effect(Msg)) {
  let capability_id = case model.task_types_create_capability_id {
    opt.None -> opt.None
    opt.Some(id_str) ->
      case int.parse(id_str) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }
  }

  let model =
    Model(
      ..model,
      task_types_create_in_flight: True,
      task_types_create_error: opt.None,
    )

  #(
    model,
    api_tasks.create_task_type(project_id, name, icon, capability_id, TaskTypeCreated),
  )
}

/// Handle task type created success.
pub fn handle_task_type_created_ok(
  model: Model,
  refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      task_types_create_in_flight: False,
      task_types_create_name: "",
      task_types_create_icon: "",
      task_types_create_capability_id: opt.None,
      task_types_icon_preview: IconIdle,
      toast: opt.Some(update_helpers.i18n_t(
        model,
        i18n_text.TaskTypeCreated,
      )),
    )

  refresh_fn(model)
}

/// Handle task type created error.
pub fn handle_task_type_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      Model(
        ..model,
        task_types_create_in_flight: False,
        task_types_create_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
      ),
      effect.none(),
    )
    _ -> #(
      Model(
        ..model,
        task_types_create_in_flight: False,
        task_types_create_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}
