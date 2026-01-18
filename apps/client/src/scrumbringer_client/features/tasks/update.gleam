//// Task mutations workflow for Scrumbringer client.
////
//// ## Mission
////
//// Manages task CRUD operations: create, claim, release, complete.
//// Handles form state, validation, API calls, and response processing.
////
//// ## Responsibilities
////
//// - Handle create task dialog state and form fields
//// - Validate task creation input
//// - Process claim/release/complete button clicks
//// - Handle API responses for task mutations
//// - Trigger data refresh after successful mutations
////
//// ## Non-responsibilities
////
//// - API request construction (see `api/tasks.gleam`)
//// - View rendering (see `client_view.gleam`)
//// - Model type definitions (see `client_state.gleam`)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg types
//// - **client_update.gleam**: Delegates task mutation messages here
//// - **api/tasks.gleam**: Provides task API functions
//// - **update_helpers.gleam**: Provides i18n_t helper

import gleam/int
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/tasks as api_tasks
// Domain types
import domain/api_error.{type ApiError}
import scrumbringer_client/client_state.{
  type Model, type Msg, MemberActiveTaskFetched, MemberTaskClaimed,
  MemberTaskCompleted, MemberTaskCreated, MemberTaskReleased, Model,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Create Dialog Handlers
// =============================================================================

/// Open the create task dialog.
pub fn handle_create_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      member_create_dialog_open: True,
      member_create_error: opt.None,
    ),
    effect.none(),
  )
}

/// Close the create task dialog.
pub fn handle_create_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      member_create_dialog_open: False,
      member_create_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle title field change.
pub fn handle_create_title_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, member_create_title: value), effect.none())
}

/// Handle description field change.
pub fn handle_create_description_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, member_create_description: value), effect.none())
}

/// Handle priority field change.
pub fn handle_create_priority_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, member_create_priority: value), effect.none())
}

/// Handle type_id field change.
pub fn handle_create_type_id_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, member_create_type_id: value), effect.none())
}

/// Handle create task form submission with validation.
///
/// ## Size Justification (~70 lines)
///
/// Sequential validation of 5 fields with i18n error messages:
/// - Project selected, title required, title length, type required, priority range.
/// Each validation step must short-circuit on error. Extracting would add
/// complexity without improving clarity.
pub fn handle_create_submitted(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  case model.member_create_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_create(model, member_refresh)
  }
}

fn validate_and_create(
  model: Model,
  _member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  case model.selected_project_id {
    opt.None -> #(
      Model(
        ..model,
        member_create_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.SelectProjectFirst,
        )),
      ),
      effect.none(),
    )

    opt.Some(project_id) -> validate_title(model, project_id)
  }
}

fn validate_title(model: Model, project_id: Int) -> #(Model, Effect(Msg)) {
  let title = string.trim(model.member_create_title)

  case title == "" {
    True -> #(
      Model(
        ..model,
        member_create_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.TitleRequired,
        )),
      ),
      effect.none(),
    )

    False -> validate_title_length(model, project_id, title)
  }
}

fn validate_title_length(
  model: Model,
  project_id: Int,
  title: String,
) -> #(Model, Effect(Msg)) {
  case string.length(title) > 56 {
    True -> #(
      Model(
        ..model,
        member_create_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.TitleTooLongMax56,
        )),
      ),
      effect.none(),
    )

    False -> validate_type_id(model, project_id, title)
  }
}

fn validate_type_id(
  model: Model,
  project_id: Int,
  title: String,
) -> #(Model, Effect(Msg)) {
  case int.parse(model.member_create_type_id) {
    Error(_) -> #(
      Model(
        ..model,
        member_create_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.TypeRequired,
        )),
      ),
      effect.none(),
    )

    Ok(type_id) -> validate_priority(model, project_id, title, type_id)
  }
}

fn validate_priority(
  model: Model,
  project_id: Int,
  title: String,
  type_id: Int,
) -> #(Model, Effect(Msg)) {
  case int.parse(model.member_create_priority) {
    Ok(priority) if priority >= 1 && priority <= 5 ->
      submit_create(model, project_id, title, type_id, priority)

    _ -> #(
      Model(
        ..model,
        member_create_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.PriorityMustBe1To5,
        )),
      ),
      effect.none(),
    )
  }
}

fn submit_create(
  model: Model,
  project_id: Int,
  title: String,
  type_id: Int,
  priority: Int,
) -> #(Model, Effect(Msg)) {
  let desc = string.trim(model.member_create_description)
  let description = case desc == "" {
    True -> opt.None
    False -> opt.Some(desc)
  }

  let model =
    Model(..model, member_create_in_flight: True, member_create_error: opt.None)

  #(
    model,
    api_tasks.create_task(
      project_id,
      title,
      description,
      priority,
      type_id,
      MemberTaskCreated,
    ),
  )
}

// =============================================================================
// Task Created Response Handlers
// =============================================================================

/// Handle successful task creation.
pub fn handle_task_created_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      member_create_in_flight: False,
      member_create_dialog_open: False,
      member_create_title: "",
      member_create_description: "",
      member_create_priority: "3",
      member_create_type_id: "",
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskCreated)),
    )
  member_refresh(model)
}

/// Handle failed task creation.
pub fn handle_task_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(
      Model(
        ..model,
        member_create_in_flight: False,
        member_create_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Claim/Release/Complete Handlers
// =============================================================================

/// Handle claim button click.
pub fn handle_claim_clicked(
  model: Model,
  task_id: Int,
  version: Int,
) -> #(Model, Effect(Msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> #(
      Model(..model, member_task_mutation_in_flight: True),
      api_tasks.claim_task(task_id, version, MemberTaskClaimed),
    )
  }
}

/// Handle release button click.
pub fn handle_release_clicked(
  model: Model,
  task_id: Int,
  version: Int,
) -> #(Model, Effect(Msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> #(
      Model(..model, member_task_mutation_in_flight: True),
      api_tasks.release_task(task_id, version, MemberTaskReleased),
    )
  }
}

/// Handle complete button click.
pub fn handle_complete_clicked(
  model: Model,
  task_id: Int,
  version: Int,
) -> #(Model, Effect(Msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> #(
      Model(..model, member_task_mutation_in_flight: True),
      api_tasks.complete_task(task_id, version, MemberTaskCompleted),
    )
  }
}

// =============================================================================
// Mutation Response Handlers
// =============================================================================

/// Handle successful task claim.
pub fn handle_task_claimed_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  member_refresh(
    Model(
      ..model,
      member_task_mutation_in_flight: False,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskClaimed)),
    ),
  )
}

/// Handle successful task release.
pub fn handle_task_released_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      member_task_mutation_in_flight: False,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskReleased)),
    )

  let #(model, fx) = member_refresh(model)
  #(model, effect.batch([fx, api_tasks.get_me_active_task(MemberActiveTaskFetched)]))
}

/// Handle successful task completion.
pub fn handle_task_completed_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      member_task_mutation_in_flight: False,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskCompleted)),
    )

  let #(model, fx) = member_refresh(model)
  #(model, effect.batch([fx, api_tasks.get_me_active_task(MemberActiveTaskFetched)]))
}

/// Handle task mutation error (claim/release/complete).
pub fn handle_mutation_error(
  model: Model,
  err: ApiError,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model = Model(..model, member_task_mutation_in_flight: False)

  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> member_refresh(Model(..model, toast: opt.Some(err.message)))
  }
}

