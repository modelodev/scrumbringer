//// Task mutations workflow for Scrumbringer client.
////
//// ## Mission
////
//// Manages task CRUD operations: create, claim, release, complete.
//// Handles form state, validation, API calls, response processing, and notes.
////
//// ## Responsibilities
////
//// - Handle create task dialog state and form fields
//// - Validate task creation input
//// - Process claim/release/complete button clicks
//// - Handle API responses for task mutations
//// - Trigger data refresh after successful mutations
//// - Handle task details/notes dialog state and form
//// - Process note creation and display
////
//// ## Optimistic Updates
////
//// Task actions (claim/release/complete) use optimistic updates:
//// 1. Snapshot current task list before mutation
//// 2. Apply visual change immediately (task removed from pool)
//// 3. Send API request
//// 4. On success: clear snapshot, refresh from server for truth
//// 5. On error: restore snapshot, show error toast
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
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/tasks as api_tasks
// Domain types
import domain/api_error.{type ApiError}
import domain/task.{type Task, type TaskNote, Task}
import domain/task_status.{Available, Claimed, Completed, Taken}
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, MemberNoteAdded,
  MemberNotesFetched, MemberTaskClaimed, MemberTaskCompleted, MemberTaskCreated,
  MemberTaskReleased, MemberWorkSessionsFetched, Model, NotAsked,
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
// Claim/Release/Complete Handlers (Optimistic Updates)
// =============================================================================

/// Handle claim button click with optimistic update.
/// Immediately marks task as claimed locally, sends API request.
pub fn handle_claim_clicked(
  model: Model,
  task_id: Int,
  version: Int,
) -> #(Model, Effect(Msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> {
      // 1. Snapshot current tasks
      let snapshot = get_tasks_snapshot(model)
      // 2. Apply optimistic update: mark task as claimed
      let model = apply_optimistic_claim(model, task_id)
      // 3. Set in-flight state with snapshot
      let model =
        Model(
          ..model,
          member_task_mutation_in_flight: True,
          member_task_mutation_task_id: opt.Some(task_id),
          member_tasks_snapshot: snapshot,
        )
      #(model, api_tasks.claim_task(task_id, version, MemberTaskClaimed))
    }
  }
}

/// Handle release button click with optimistic update.
/// Immediately marks task as available locally, sends API request.
pub fn handle_release_clicked(
  model: Model,
  task_id: Int,
  version: Int,
) -> #(Model, Effect(Msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> {
      // 1. Snapshot current tasks
      let snapshot = get_tasks_snapshot(model)
      // 2. Apply optimistic update: mark task as available
      let model = apply_optimistic_release(model, task_id)
      // 3. Set in-flight state with snapshot
      let model =
        Model(
          ..model,
          member_task_mutation_in_flight: True,
          member_task_mutation_task_id: opt.Some(task_id),
          member_tasks_snapshot: snapshot,
        )
      #(model, api_tasks.release_task(task_id, version, MemberTaskReleased))
    }
  }
}

/// Handle complete button click with optimistic update.
/// Immediately marks task as completed locally, sends API request.
pub fn handle_complete_clicked(
  model: Model,
  task_id: Int,
  version: Int,
) -> #(Model, Effect(Msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> {
      // 1. Snapshot current tasks
      let snapshot = get_tasks_snapshot(model)
      // 2. Apply optimistic update: mark task as completed
      let model = apply_optimistic_complete(model, task_id)
      // 3. Set in-flight state with snapshot
      let model =
        Model(
          ..model,
          member_task_mutation_in_flight: True,
          member_task_mutation_task_id: opt.Some(task_id),
          member_tasks_snapshot: snapshot,
        )
      #(model, api_tasks.complete_task(task_id, version, MemberTaskCompleted))
    }
  }
}

// =============================================================================
// Optimistic Update Helpers
// =============================================================================

/// Extract current tasks list for snapshot.
fn get_tasks_snapshot(model: Model) -> opt.Option(List(Task)) {
  case model.member_tasks {
    Loaded(tasks) -> opt.Some(tasks)
    _ -> opt.None
  }
}

/// Apply optimistic claim: mark task as Claimed(Taken).
fn apply_optimistic_claim(model: Model, task_id: Int) -> Model {
  case model.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True ->
              Task(
                ..t,
                status: Claimed(Taken),
                claimed_by: model.user
                  |> opt.map(fn(u) { u.id }),
              )
            False -> t
          }
        })
      Model(..model, member_tasks: Loaded(updated))
    }
    _ -> model
  }
}

/// Apply optimistic release: mark task as Available.
fn apply_optimistic_release(model: Model, task_id: Int) -> Model {
  case model.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True -> Task(..t, status: Available, claimed_by: opt.None)
            False -> t
          }
        })
      Model(..model, member_tasks: Loaded(updated))
    }
    _ -> model
  }
}

/// Apply optimistic complete: mark task as Completed.
fn apply_optimistic_complete(model: Model, task_id: Int) -> Model {
  case model.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True -> Task(..t, status: Completed)
            False -> t
          }
        })
      Model(..model, member_tasks: Loaded(updated))
    }
    _ -> model
  }
}

/// Restore tasks from snapshot (rollback on error).
fn restore_from_snapshot(model: Model) -> Model {
  case model.member_tasks_snapshot {
    opt.Some(tasks) -> Model(..model, member_tasks: Loaded(tasks))
    opt.None -> model
  }
}

// =============================================================================
// Mutation Response Handlers
// =============================================================================

/// Clear optimistic state after successful mutation.
fn clear_optimistic_state(model: Model) -> Model {
  Model(
    ..model,
    member_task_mutation_in_flight: False,
    member_task_mutation_task_id: opt.None,
    member_tasks_snapshot: opt.None,
  )
}

/// Handle successful task claim.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_claimed_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model = clear_optimistic_state(model)
  let model =
    Model(
      ..model,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskClaimed)),
    )
  member_refresh(model)
}

/// Handle successful task release.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_released_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model = clear_optimistic_state(model)
  let model =
    Model(
      ..model,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskReleased)),
    )

  let #(model, fx) = member_refresh(model)
  #(model, effect.batch([fx, api_tasks.get_work_sessions(MemberWorkSessionsFetched)]))
}

/// Handle successful task completion.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_completed_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model = clear_optimistic_state(model)
  let model =
    Model(
      ..model,
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.TaskCompleted)),
    )

  let #(model, fx) = member_refresh(model)
  #(model, effect.batch([fx, api_tasks.get_work_sessions(MemberWorkSessionsFetched)]))
}

/// Handle task mutation error (claim/release/complete).
/// Restores task list from snapshot (rollback) and shows error toast.
pub fn handle_mutation_error(
  model: Model,
  err: ApiError,
  _member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  // Rollback: restore tasks from snapshot
  let model = restore_from_snapshot(model)
  // Clear optimistic state
  let model = clear_optimistic_state(model)

  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, toast: opt.Some(err.message)), effect.none())
  }
}

// =============================================================================
// Task Details / Notes Handlers
// =============================================================================

/// Open task details dialog and fetch notes.
pub fn handle_task_details_opened(
  model: Model,
  task_id: Int,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      member_notes_task_id: opt.Some(task_id),
      member_notes: Loading,
      member_note_error: opt.None,
    ),
    api_tasks.list_task_notes(task_id, MemberNotesFetched),
  )
}

/// Close task details dialog.
pub fn handle_task_details_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      member_notes_task_id: opt.None,
      member_notes: NotAsked,
      member_note_content: "",
      member_note_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle notes fetched response (success).
pub fn handle_notes_fetched_ok(
  model: Model,
  notes: List(TaskNote),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, member_notes: Loaded(notes)), effect.none())
}

/// Handle notes fetched response (error).
pub fn handle_notes_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> #(Model(..model, member_notes: Failed(err)), effect.none())
  }
}

/// Handle note content field change.
pub fn handle_note_content_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, member_note_content: value), effect.none())
}

/// Handle note form submission.
pub fn handle_note_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.member_note_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.member_notes_task_id {
        opt.None -> #(model, effect.none())
        opt.Some(task_id) -> {
          let content = string.trim(model.member_note_content)
          case content == "" {
            True -> #(
              Model(
                ..model,
                member_note_error: opt.Some(update_helpers.i18n_t(
                  model,
                  i18n_text.ContentRequired,
                )),
              ),
              effect.none(),
            )
            False -> {
              let model =
                Model(
                  ..model,
                  member_note_in_flight: True,
                  member_note_error: opt.None,
                )
              #(model, api_tasks.add_task_note(task_id, content, MemberNoteAdded))
            }
          }
        }
      }
  }
}

/// Handle note added response (success).
pub fn handle_note_added_ok(
  model: Model,
  note: TaskNote,
) -> #(Model, Effect(Msg)) {
  let updated = case model.member_notes {
    Loaded(notes) -> [note, ..notes]
    _ -> [note]
  }

  #(
    Model(
      ..model,
      member_note_in_flight: False,
      member_note_content: "",
      member_notes: Loaded(updated),
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NoteAdded)),
    ),
    effect.none(),
  )
}

/// Handle note added response (error).
pub fn handle_note_added_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    _ -> {
      let model =
        Model(
          ..model,
          member_note_in_flight: False,
          member_note_error: opt.Some(err.message),
        )

      case model.member_notes_task_id {
        opt.Some(task_id) -> #(
          model,
          api_tasks.list_task_notes(task_id, MemberNotesFetched),
        )
        opt.None -> #(model, effect.none())
      }
    }
  }
}

