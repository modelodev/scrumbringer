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
  type Model, type Msg, Failed, Loaded, Loading, MemberModel, MemberNoteAdded,
  MemberNotesFetched, MemberTaskClaimed, MemberTaskCompleted, MemberTaskCreated,
  MemberTaskReleased, MemberWorkSessionsFetched, NotAsked, pool_msg,
  update_member,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Create Dialog Handlers
// =============================================================================

/// Open the create task dialog.
pub fn handle_create_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_create_dialog_open: True,
        member_create_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Close the create task dialog.
pub fn handle_create_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_create_dialog_open: False,
        member_create_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle title field change.
pub fn handle_create_title_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_create_title: value)
    }),
    effect.none(),
  )
}

/// Handle description field change.
pub fn handle_create_description_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_create_description: value)
    }),
    effect.none(),
  )
}

/// Handle priority field change.
pub fn handle_create_priority_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_create_priority: value)
    }),
    effect.none(),
  )
}

/// Handle type_id field change.
pub fn handle_create_type_id_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_create_type_id: value)
    }),
    effect.none(),
  )
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
  case model.member.member_create_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_create(model, member_refresh)
  }
}

fn validate_and_create(
  model: Model,
  _member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  case model.core.selected_project_id {
    opt.None -> #(
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_create_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.SelectProjectFirst,
          )),
        )
      }),
      effect.none(),
    )

    opt.Some(project_id) -> validate_title(model, project_id)
  }
}

fn validate_title(model: Model, project_id: Int) -> #(Model, Effect(Msg)) {
  let title = string.trim(model.member.member_create_title)

  case title == "" {
    True -> #(
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_create_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.TitleRequired,
          )),
        )
      }),
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
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_create_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.TitleTooLongMax56,
          )),
        )
      }),
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
  case int.parse(model.member.member_create_type_id) {
    Error(_) -> #(
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_create_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.TypeRequired,
          )),
        )
      }),
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
  case int.parse(model.member.member_create_priority) {
    Ok(priority) if priority >= 1 && priority <= 5 ->
      submit_create(model, project_id, title, type_id, priority)

    _ -> #(
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_create_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.PriorityMustBe1To5,
          )),
        )
      }),
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
  let desc = string.trim(model.member.member_create_description)
  let description = case desc == "" {
    True -> opt.None
    False -> opt.Some(desc)
  }

  let model =
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_create_in_flight: True,
        member_create_error: opt.None,
      )
    })

  #(
    model,
    api_tasks.create_task(
      project_id,
      title,
      description,
      priority,
      type_id,
      fn(result) { pool_msg(MemberTaskCreated(result)) },
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
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_create_in_flight: False,
        member_create_dialog_open: False,
        member_create_title: "",
        member_create_description: "",
        member_create_priority: "3",
        member_create_type_id: "",
      )
    })
  let #(model, refresh_fx) = member_refresh(model)
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.TaskCreated,
    ))
  #(model, effect.batch([refresh_fx, toast_fx]))
}

/// Handle failed task creation.
pub fn handle_task_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_create_in_flight: False,
          member_create_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  })
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
  case model.member.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> {
      // 1. Snapshot current tasks
      let snapshot = get_tasks_snapshot(model)
      // 2. Apply optimistic update: mark task as claimed
      let model = apply_optimistic_claim(model, task_id)
      // 3. Set in-flight state with snapshot
      let model =
        update_member(model, fn(member) {
          MemberModel(
            ..member,
            member_task_mutation_in_flight: True,
            member_task_mutation_task_id: opt.Some(task_id),
            member_tasks_snapshot: snapshot,
          )
        })
      #(
        model,
        api_tasks.claim_task(task_id, version, fn(result) {
          pool_msg(MemberTaskClaimed(result))
        }),
      )
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
  case model.member.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> {
      // 1. Snapshot current tasks
      let snapshot = get_tasks_snapshot(model)
      // 2. Apply optimistic update: mark task as available
      let model = apply_optimistic_release(model, task_id)
      // 3. Set in-flight state with snapshot
      let model =
        update_member(model, fn(member) {
          MemberModel(
            ..member,
            member_task_mutation_in_flight: True,
            member_task_mutation_task_id: opt.Some(task_id),
            member_tasks_snapshot: snapshot,
          )
        })
      #(
        model,
        api_tasks.release_task(task_id, version, fn(result) {
          pool_msg(MemberTaskReleased(result))
        }),
      )
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
  case model.member.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> {
      // 1. Snapshot current tasks
      let snapshot = get_tasks_snapshot(model)
      // 2. Apply optimistic update: mark task as completed
      let model = apply_optimistic_complete(model, task_id)
      // 3. Set in-flight state with snapshot
      let model =
        update_member(model, fn(member) {
          MemberModel(
            ..member,
            member_task_mutation_in_flight: True,
            member_task_mutation_task_id: opt.Some(task_id),
            member_tasks_snapshot: snapshot,
          )
        })
      #(
        model,
        api_tasks.complete_task(task_id, version, fn(result) {
          pool_msg(MemberTaskCompleted(result))
        }),
      )
    }
  }
}

// =============================================================================
// Optimistic Update Helpers
// =============================================================================

/// Extract current tasks list for snapshot.
fn get_tasks_snapshot(model: Model) -> opt.Option(List(Task)) {
  case model.member.member_tasks {
    Loaded(tasks) -> opt.Some(tasks)
    _ -> opt.None
  }
}

// Justification: nested case improves clarity for branching logic.
/// Apply optimistic claim: mark task as Claimed(Taken).
fn apply_optimistic_claim(model: Model, task_id: Int) -> Model {
  case model.member.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True ->
              Task(
                ..t,
                status: Claimed(Taken),
                claimed_by: model.core.user
                  |> opt.map(fn(u) { u.id }),
              )
            False -> t
          }
        })
      update_member(model, fn(member) {
        MemberModel(..member, member_tasks: Loaded(updated))
      })
    }
    _ -> model
  }
}

// Justification: nested case improves clarity for branching logic.
/// Apply optimistic release: mark task as Available.
fn apply_optimistic_release(model: Model, task_id: Int) -> Model {
  case model.member.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True -> Task(..t, status: Available, claimed_by: opt.None)
            False -> t
          }
        })
      update_member(model, fn(member) {
        MemberModel(..member, member_tasks: Loaded(updated))
      })
    }
    _ -> model
  }
}

// Justification: nested case improves clarity for branching logic.
/// Apply optimistic complete: mark task as Completed.
fn apply_optimistic_complete(model: Model, task_id: Int) -> Model {
  case model.member.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True -> Task(..t, status: Completed)
            False -> t
          }
        })
      update_member(model, fn(member) {
        MemberModel(..member, member_tasks: Loaded(updated))
      })
    }
    _ -> model
  }
}

/// Restore tasks from snapshot (rollback on error).
fn restore_from_snapshot(model: Model) -> Model {
  case model.member.member_tasks_snapshot {
    opt.Some(tasks) ->
      update_member(model, fn(member) {
        MemberModel(..member, member_tasks: Loaded(tasks))
      })
    opt.None -> model
  }
}

// =============================================================================
// Mutation Response Handlers
// =============================================================================

/// Clear optimistic state after successful mutation.
fn clear_optimistic_state(model: Model) -> Model {
  update_member(model, fn(member) {
    MemberModel(
      ..member,
      member_task_mutation_in_flight: False,
      member_task_mutation_task_id: opt.None,
      member_tasks_snapshot: opt.None,
    )
  })
}

/// Handle successful task claim.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_claimed_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model = clear_optimistic_state(model)
  let #(model, refresh_fx) = member_refresh(model)
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.TaskClaimed,
    ))
  #(model, effect.batch([refresh_fx, toast_fx]))
}

/// Handle successful task release.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_released_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model = clear_optimistic_state(model)
  let #(model, fx) = member_refresh(model)
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.TaskReleased,
    ))
  #(
    model,
    effect.batch([
      fx,
      api_tasks.get_work_sessions(fn(result) {
        pool_msg(MemberWorkSessionsFetched(result))
      }),
      toast_fx,
    ]),
  )
}

/// Handle successful task completion.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_completed_ok(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model = clear_optimistic_state(model)
  let #(model, fx) = member_refresh(model)
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.TaskCompleted,
    ))
  #(
    model,
    effect.batch([
      fx,
      api_tasks.get_work_sessions(fn(result) {
        pool_msg(MemberWorkSessionsFetched(result))
      }),
      toast_fx,
    ]),
  )
}

/// Handle task mutation error (claim/release/complete).
/// Restores task list from snapshot (rollback) and shows error toast.
/// Provides user-friendly error messages based on error code.
pub fn handle_mutation_error(
  model: Model,
  err: ApiError,
  _member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  // Rollback: restore tasks from snapshot
  let model = restore_from_snapshot(model)
  // Clear optimistic state
  let model = clear_optimistic_state(model)

  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      404 -> #(
        model,
        update_helpers.toast_warning(update_helpers.i18n_t(
          model,
          i18n_text.TaskNotFound,
        )),
      )
      409 -> {
        // Conflict - task already claimed
        let msg = case string.contains(err.code, "CLAIMED") {
          True -> update_helpers.i18n_t(model, i18n_text.TaskAlreadyClaimed)
          False -> update_helpers.i18n_t(model, i18n_text.TaskVersionConflict)
        }
        #(model, update_helpers.toast_warning(msg))
      }
      422 -> {
        // Version conflict or validation error
        let msg = case string.contains(err.code, "VERSION") {
          True -> update_helpers.i18n_t(model, i18n_text.TaskVersionConflict)
          False -> err.message
        }
        #(model, update_helpers.toast_warning(msg))
      }
      _ -> {
        // Show rollback notice + original error
        let msg =
          update_helpers.i18n_t(model, i18n_text.TaskMutationRolledBack)
          <> ": "
          <> err.message
        #(model, update_helpers.toast_error(msg))
      }
    }
  })
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
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_notes_task_id: opt.Some(task_id),
        member_notes: Loading,
        member_note_error: opt.None,
      )
    }),
    api_tasks.list_task_notes(task_id, fn(result) {
      pool_msg(MemberNotesFetched(result))
    }),
  )
}

/// Close task details dialog.
pub fn handle_task_details_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_notes_task_id: opt.None,
        member_notes: NotAsked,
        member_note_content: "",
        member_note_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle notes fetched response (success).
pub fn handle_notes_fetched_ok(
  model: Model,
  notes: List(TaskNote),
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_notes: Loaded(notes))
    }),
    effect.none(),
  )
}

/// Handle notes fetched response (error).
pub fn handle_notes_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    #(
      update_member(model, fn(member) {
        MemberModel(..member, member_notes: Failed(err))
      }),
      effect.none(),
    )
  })
}

/// Handle note content field change.
pub fn handle_note_content_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(..member, member_note_content: value)
    }),
    effect.none(),
  )
}

/// Handle note form submission.
pub fn handle_note_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.member_note_in_flight {
    True -> #(model, effect.none())
    False -> submit_note(model)
  }
}

fn submit_note(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.member_notes_task_id {
    opt.None -> #(model, effect.none())
    opt.Some(task_id) -> submit_note_for_task(model, task_id)
  }
}

fn submit_note_for_task(model: Model, task_id: Int) -> #(Model, Effect(Msg)) {
  let content = string.trim(model.member.member_note_content)
  case content == "" {
    True -> submit_note_missing_content(model)
    False -> submit_note_with_content(model, task_id, content)
  }
}

fn submit_note_missing_content(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_note_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.ContentRequired,
        )),
      )
    }),
    effect.none(),
  )
}

fn submit_note_with_content(
  model: Model,
  task_id: Int,
  content: String,
) -> #(Model, Effect(Msg)) {
  let model =
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_note_in_flight: True,
        member_note_error: opt.None,
      )
    })
  #(
    model,
    api_tasks.add_task_note(task_id, content, fn(result) {
      pool_msg(MemberNoteAdded(result))
    }),
  )
}

/// Handle note added response (success).
pub fn handle_note_added_ok(
  model: Model,
  note: TaskNote,
) -> #(Model, Effect(Msg)) {
  let updated = case model.member.member_notes {
    Loaded(notes) -> [note, ..notes]
    _ -> [note]
  }

  let model =
    update_member(model, fn(member) {
      MemberModel(
        ..member,
        member_note_in_flight: False,
        member_note_content: "",
        member_notes: Loaded(updated),
      )
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.NoteAdded,
    ))
  #(model, toast_fx)
}

/// Handle note added response (error).
pub fn handle_note_added_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    let model =
      update_member(model, fn(member) {
        MemberModel(
          ..member,
          member_note_in_flight: False,
          member_note_error: opt.Some(err.message),
        )
      })

    case model.member.member_notes_task_id {
      opt.Some(task_id) -> #(
        model,
        api_tasks.list_task_notes(task_id, fn(result) {
          pool_msg(MemberNotesFetched(result))
        }),
      )
      opt.None -> #(model, effect.none())
    }
  })
}
