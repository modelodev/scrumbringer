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
//// - **helpers/i18n.gleam**: Provides i18n_t helper

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/tasks as api_tasks
import scrumbringer_client/app/effects as app_effects

// Domain types
import domain/api_error.{type ApiError}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{
  type Task, type TaskDependency, type TaskNote, Task, TaskFilters, with_state,
}
import domain/task_state
import domain/task_status.{Completed, Taken}
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/client_state.{
  type Model, type Msg, pool_msg, update_member,
}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member.{MemberModel}
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/toast as helpers_toast
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/task_tabs
import scrumbringer_client/ui/toast

const created_highlight_ms = 4000

// =============================================================================
// Create Dialog Handlers
// =============================================================================

/// Open the create task dialog.
pub fn handle_create_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_create_dialog_mode: dialog_mode.DialogCreate,
        member_create_error: opt.None,
        member_create_card_id: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Open the create task dialog with a pre-selected card (Story 4.12 AC7, AC9).
pub fn handle_create_dialog_opened_with_card(
  model: Model,
  card_id: Int,
) -> #(Model, Effect(Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_create_dialog_mode: dialog_mode.DialogCreate,
        member_create_error: opt.None,
        member_create_card_id: opt.Some(card_id),
      )
    }),
    effect.none(),
  )
}

/// Close the create task dialog.
pub fn handle_create_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_create_dialog_mode: dialog_mode.DialogClosed,
        member_create_error: opt.None,
        member_create_card_id: opt.None,
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
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_create_title: value)
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
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_create_description: value)
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
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_create_priority: value)
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
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_create_type_id: value)
    }),
    effect.none(),
  )
}

/// Handle card_id field change (Story 4.12).
pub fn handle_create_card_id_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  let card_id = case int.parse(value) {
    Ok(id) if id > 0 -> opt.Some(id)
    _ -> opt.None
  }
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_create_card_id: card_id)
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
  case model.member.pool.member_create_in_flight {
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
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_create_error: opt.Some(helpers_i18n.i18n_t(
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
  let title = string.trim(model.member.pool.member_create_title)

  case title == "" {
    True -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_create_error: opt.Some(helpers_i18n.i18n_t(
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
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_create_error: opt.Some(helpers_i18n.i18n_t(
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
  case int.parse(model.member.pool.member_create_type_id) {
    Error(_) -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_create_error: opt.Some(helpers_i18n.i18n_t(
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
  case int.parse(model.member.pool.member_create_priority) {
    Ok(priority) if priority >= 1 && priority <= 5 ->
      submit_create(model, project_id, title, type_id, priority)

    _ -> #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
          member_create_error: opt.Some(helpers_i18n.i18n_t(
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
  let desc = string.trim(model.member.pool.member_create_description)
  let description = case desc == "" {
    True -> opt.None
    False -> opt.Some(desc)
  }

  // Story 4.12: Include card_id in task creation
  let card_id = model.member.pool.member_create_card_id

  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_create_in_flight: True,
        member_create_error: opt.None,
      )
    })

  #(
    model,
    api_tasks.create_task_with_card(
      project_id,
      title,
      description,
      priority,
      type_id,
      card_id,
      fn(result) { pool_msg(pool_messages.MemberTaskCreated(result)) },
    ),
  )
}

// =============================================================================
// Task Created Response Handlers
// =============================================================================

/// Handle successful task creation.
pub fn handle_task_created_ok(
  model: Model,
  task: Task,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_create_in_flight: False,
        member_create_dialog_mode: dialog_mode.DialogClosed,
        member_create_title: "",
        member_create_description: "",
        member_create_priority: "3",
        member_create_type_id: "",
        member_create_card_id: opt.None,
      )
    })
  let #(model, refresh_fx) = member_refresh(model)

  let #(toast_message, toast_variant, toast_action) =
    task_created_feedback(model, task)

  let toast_fx =
    helpers_toast.toast_effect_with_action(
      toast_message,
      toast_variant,
      toast_action,
    )

  let feedback_fx =
    effect.from(fn(dispatch) {
      dispatch(pool_msg(pool_messages.MemberTaskCreatedFeedback(task.id)))
    })

  let expire_fx =
    app_effects.schedule_timeout(created_highlight_ms, fn() {
      pool_msg(pool_messages.MemberHighlightExpired(task.id))
    })

  #(model, effect.batch([refresh_fx, feedback_fx, expire_fx, toast_fx]))
}

fn task_created_feedback(
  model: Model,
  task: Task,
) -> #(String, toast.ToastVariant, toast.ToastAction) {
  case is_task_visible_under_active_filters(model, task) {
    True -> #(
      helpers_i18n.i18n_t(model, i18n_text.TaskCreated),
      toast.Success,
      toast.ToastAction(
        label: helpers_i18n.i18n_t(model, i18n_text.View),
        kind: toast.ViewTask(task.id),
      ),
    )

    False -> #(
      helpers_i18n.i18n_t(model, i18n_text.TaskCreatedNotVisibleByFilters),
      toast.Info,
      toast.ToastAction(
        label: helpers_i18n.i18n_t(model, i18n_text.ClearFilters),
        kind: toast.ClearPoolFilters,
      ),
    )
  }
}

pub fn task_created_feedback_for_test(
  model: Model,
  task: Task,
) -> #(String, toast.ToastVariant, toast.ToastAction) {
  task_created_feedback(model, task)
}

fn is_task_visible_under_active_filters(model: Model, task: Task) -> Bool {
  let status_ok = case model.member.pool.member_filters_status {
    opt.Some(status) -> task.status == status
    opt.None -> True
  }

  let type_ok = case model.member.pool.member_filters_type_id {
    opt.Some(type_id) -> task.type_id == type_id
    opt.None -> True
  }

  let capability_ok =
    matches_capability_filter(
      model.member.pool.member_filters_capability_id,
      model.member.pool.member_task_types,
      task.type_id,
    )

  let query_ok = case string.trim(model.member.pool.member_filters_q) {
    "" -> True
    q -> {
      let q_lower = string.lowercase(q)
      let in_title = string.contains(string.lowercase(task.title), q_lower)
      let in_description = case task.description {
        opt.Some(description) ->
          string.contains(string.lowercase(description), q_lower)
        opt.None -> False
      }
      in_title || in_description
    }
  }

  status_ok && type_ok && capability_ok && query_ok
}

pub fn is_task_visible_under_active_filters_for_test(
  model: Model,
  task: Task,
) -> Bool {
  is_task_visible_under_active_filters(model, task)
}

fn matches_capability_filter(
  selected_capability_id: opt.Option(Int),
  task_types_remote: Remote(List(TaskType)),
  task_type_id: Int,
) -> Bool {
  case selected_capability_id {
    opt.None -> True
    opt.Some(capability_id) ->
      case task_types_remote {
        Loaded(task_types) ->
          case list.find(task_types, fn(t) { t.id == task_type_id }) {
            Ok(TaskType(capability_id: opt.Some(task_capability_id), ..)) ->
              task_capability_id == capability_id
            _ -> False
          }
        _ -> False
      }
  }
}

/// Handle failed task creation.
pub fn handle_task_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member_pool(model, fn(pool) {
        member_pool.Model(
          ..pool,
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
  case model.member.pool.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False ->
      case
        helpers_lookup.find_task_by_id(model.member.pool.member_tasks, task_id)
      {
        opt.Some(Task(blocked_count: blocked_count, ..)) if blocked_count > 0 -> #(
          update_member_pool(model, fn(pool) {
            member_pool.Model(
              ..pool,
              member_blocked_claim_task: opt.Some(#(task_id, version)),
            )
          }),
          effect.none(),
        )
        _ -> submit_claim(model, task_id, version)
      }
  }
}

pub fn handle_blocked_claim_cancelled(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_blocked_claim_task: opt.None)
    }),
    effect.none(),
  )
}

pub fn handle_blocked_claim_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.pool.member_blocked_claim_task {
    opt.None -> #(model, effect.none())
    opt.Some(#(task_id, version)) -> {
      let #(model, fx) = submit_claim(model, task_id, version)
      #(
        update_member_pool(model, fn(pool) {
          member_pool.Model(..pool, member_blocked_claim_task: opt.None)
        }),
        fx,
      )
    }
  }
}

fn submit_claim(
  model: Model,
  task_id: Int,
  version: Int,
) -> #(Model, Effect(Msg)) {
  // 1. Snapshot current tasks
  let snapshot = get_tasks_snapshot(model)
  // 2. Apply optimistic update: mark task as claimed
  let model = apply_optimistic_claim(model, task_id)
  // 3. Set in-flight state with snapshot
  let model =
    update_member_pool(model, fn(pool) {
      member_pool.Model(
        ..pool,
        member_task_mutation_in_flight: True,
        member_task_mutation_task_id: opt.Some(task_id),
        member_tasks_snapshot: snapshot,
      )
    })
  #(
    model,
    api_tasks.claim_task(task_id, version, fn(result) {
      pool_msg(pool_messages.MemberTaskClaimed(result))
    }),
  )
}

/// Handle release button click with optimistic update.
/// Immediately marks task as available locally, sends API request.
pub fn handle_release_clicked(
  model: Model,
  task_id: Int,
  version: Int,
) -> #(Model, Effect(Msg)) {
  case model.member.pool.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> {
      // 1. Snapshot current tasks
      let snapshot = get_tasks_snapshot(model)
      // 2. Apply optimistic update: mark task as available
      let model = apply_optimistic_release(model, task_id)
      // 3. Set in-flight state with snapshot
      let model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_task_mutation_in_flight: True,
            member_task_mutation_task_id: opt.Some(task_id),
            member_tasks_snapshot: snapshot,
          )
        })
      #(
        model,
        api_tasks.release_task(task_id, version, fn(result) {
          pool_msg(pool_messages.MemberTaskReleased(result))
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
  case model.member.pool.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> {
      // 1. Snapshot current tasks
      let snapshot = get_tasks_snapshot(model)
      // 2. Apply optimistic update: mark task as completed
      let model = apply_optimistic_complete(model, task_id)
      // 3. Set in-flight state with snapshot
      let model =
        update_member_pool(model, fn(pool) {
          member_pool.Model(
            ..pool,
            member_task_mutation_in_flight: True,
            member_task_mutation_task_id: opt.Some(task_id),
            member_tasks_snapshot: snapshot,
          )
        })
      #(
        model,
        api_tasks.complete_task(task_id, version, fn(result) {
          pool_msg(pool_messages.MemberTaskCompleted(result))
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
  case model.member.pool.member_tasks {
    Loaded(tasks) -> opt.Some(tasks)
    _ -> opt.None
  }
}

// Justification: nested case improves clarity for branching logic.
/// Apply optimistic claim: mark task as Claimed(Taken).
fn apply_optimistic_claim(model: Model, task_id: Int) -> Model {
  case model.member.pool.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True ->
              case model.core.user {
                opt.Some(user) ->
                  with_state(
                    t,
                    task_state.Claimed(
                      claimed_by: user.id,
                      claimed_at: "",
                      mode: Taken,
                    ),
                  )
                opt.None -> t
              }
            False -> t
          }
        })
      update_member_pool(model, fn(pool) {
        member_pool.Model(..pool, member_tasks: Loaded(updated))
      })
    }
    _ -> model
  }
}

// Justification: nested case improves clarity for branching logic.
/// Apply optimistic release: mark task as Available.
fn apply_optimistic_release(model: Model, task_id: Int) -> Model {
  case model.member.pool.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True -> with_state(t, task_state.Available)
            False -> t
          }
        })
      update_member_pool(model, fn(pool) {
        member_pool.Model(..pool, member_tasks: Loaded(updated))
      })
    }
    _ -> model
  }
}

// Justification: nested case improves clarity for branching logic.
/// Apply optimistic complete: mark task as Completed.
fn apply_optimistic_complete(model: Model, task_id: Int) -> Model {
  case model.member.pool.member_tasks {
    Loaded(tasks) -> {
      let updated =
        list.map(tasks, fn(t) {
          case t.id == task_id {
            True -> with_state(t, task_state.Completed(completed_at: ""))
            False -> t
          }
        })
      update_member_pool(model, fn(pool) {
        member_pool.Model(..pool, member_tasks: Loaded(updated))
      })
    }
    _ -> model
  }
}

/// Restore tasks from snapshot (rollback on error).
fn restore_from_snapshot(model: Model) -> Model {
  case model.member.pool.member_tasks_snapshot {
    opt.Some(tasks) ->
      update_member_pool(model, fn(pool) {
        member_pool.Model(..pool, member_tasks: Loaded(tasks))
      })
    opt.None -> model
  }
}

// =============================================================================
// Mutation Response Handlers
// =============================================================================

/// Clear optimistic state after successful mutation.
fn clear_optimistic_state(model: Model) -> Model {
  update_member_pool(model, fn(pool) {
    member_pool.Model(
      ..pool,
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
    helpers_toast.toast_success(helpers_i18n.i18n_t(
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
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskReleased,
    ))
  #(
    model,
    effect.batch([
      fx,
      api_tasks.get_work_sessions(fn(result) {
        pool_msg(pool_messages.MemberWorkSessionsFetched(result))
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
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskCompleted,
    ))
  #(
    model,
    effect.batch([
      fx,
      api_tasks.get_work_sessions(fn(result) {
        pool_msg(pool_messages.MemberWorkSessionsFetched(result))
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

  helpers_auth.handle_401_or(model, err, fn() {
    case err.status {
      404 -> #(
        model,
        helpers_toast.toast_warning(helpers_i18n.i18n_t(
          model,
          i18n_text.TaskNotFound,
        )),
      )
      409 -> {
        // Conflict - task already claimed
        let msg = case string.contains(err.code, "CLAIMED") {
          True -> helpers_i18n.i18n_t(model, i18n_text.TaskAlreadyClaimed)
          False -> helpers_i18n.i18n_t(model, i18n_text.TaskVersionConflict)
        }
        #(model, helpers_toast.toast_warning(msg))
      }
      422 -> {
        // Version conflict or validation error
        let msg = case string.contains(err.code, "VERSION") {
          True -> helpers_i18n.i18n_t(model, i18n_text.TaskVersionConflict)
          False -> err.message
        }
        #(model, helpers_toast.toast_warning(msg))
      }
      _ -> {
        // Show rollback notice + original error
        let msg =
          helpers_i18n.i18n_t(model, i18n_text.TaskMutationRolledBack)
          <> ": "
          <> err.message
        #(model, helpers_toast.toast_error(msg))
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
  let next_model =
    update_member(model, fn(member) {
      let notes = member.notes
      let dependencies = member.dependencies

      MemberModel(
        ..member,
        notes: member_notes.Model(
          ..notes,
          member_notes_task_id: opt.Some(task_id),
          member_notes: Loading,
          member_note_error: opt.None,
        ),
        dependencies: member_dependencies.Model(
          ..dependencies,
          member_dependencies: Loading,
          member_dependency_add_error: opt.None,
          member_dependency_remove_in_flight: opt.None,
        ),
      )
    })

  let notes_fx =
    api_tasks.list_task_notes(task_id, fn(result) {
      pool_msg(pool_messages.MemberNotesFetched(result))
    })

  let deps_fx =
    api_tasks.list_task_dependencies(task_id, fn(result) {
      pool_msg(pool_messages.MemberDependenciesFetched(result))
    })

  #(next_model, effect.batch([notes_fx, deps_fx]))
}

/// Close task details dialog.
pub fn handle_task_details_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member(model, fn(member) {
      let notes = member.notes

      MemberModel(
        ..member,
        notes: member_notes.Model(
          ..notes,
          member_notes_task_id: opt.None,
          member_notes: NotAsked,
          member_note_content: "",
          member_note_error: opt.None,
          member_note_dialog_mode: dialog_mode.DialogClosed,
        ),
        dependencies: member_dependencies.Model(
          member_dependencies: NotAsked,
          member_dependency_dialog_mode: dialog_mode.DialogClosed,
          member_dependency_search_query: "",
          member_dependency_candidates: NotAsked,
          member_dependency_selected_task_id: opt.None,
          member_dependency_add_in_flight: False,
          member_dependency_add_error: opt.None,
          member_dependency_remove_in_flight: opt.None,
        ),
      )
    }),
    effect.none(),
  )
}

/// Handle task detail tab click.
pub fn handle_task_detail_tab_clicked(
  model: Model,
  tab: task_tabs.Tab,
) -> #(Model, Effect(Msg)) {
  #(
    update_member_pool(model, fn(pool) {
      member_pool.Model(..pool, member_task_detail_tab: tab)
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
    update_member_notes(model, fn(notes_state) {
      member_notes.Model(..notes_state, member_notes: Loaded(notes))
    }),
    effect.none(),
  )
}

/// Handle notes fetched response (error).
pub fn handle_notes_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member_notes(model, fn(notes_state) {
        member_notes.Model(..notes_state, member_notes: Failed(err))
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
    update_member_notes(model, fn(notes_state) {
      member_notes.Model(..notes_state, member_note_content: value)
    }),
    effect.none(),
  )
}

/// Handle note dialog opened (Story 5.4 UX unification).
pub fn handle_note_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member_notes(model, fn(notes_state) {
      member_notes.Model(
        ..notes_state,
        member_note_dialog_mode: dialog_mode.DialogCreate,
        member_note_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle note dialog closed (Story 5.4 UX unification).
pub fn handle_note_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member_notes(model, fn(notes_state) {
      member_notes.Model(
        ..notes_state,
        member_note_dialog_mode: dialog_mode.DialogClosed,
        member_note_content: "",
        member_note_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle note form submission.
pub fn handle_note_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.notes.member_note_in_flight {
    True -> #(model, effect.none())
    False -> submit_note(model)
  }
}

fn submit_note(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.notes.member_notes_task_id {
    opt.None -> #(model, effect.none())
    opt.Some(task_id) -> submit_note_for_task(model, task_id)
  }
}

fn submit_note_for_task(model: Model, task_id: Int) -> #(Model, Effect(Msg)) {
  let content = string.trim(model.member.notes.member_note_content)
  case content == "" {
    True -> submit_note_missing_content(model)
    False -> submit_note_with_content(model, task_id, content)
  }
}

fn submit_note_missing_content(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member_notes(model, fn(notes_state) {
      member_notes.Model(
        ..notes_state,
        member_note_error: opt.Some(helpers_i18n.i18n_t(
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
    update_member_notes(model, fn(notes_state) {
      member_notes.Model(
        ..notes_state,
        member_note_in_flight: True,
        member_note_error: opt.None,
      )
    })
  #(
    model,
    api_tasks.add_task_note(task_id, content, fn(result) {
      pool_msg(pool_messages.MemberNoteAdded(result))
    }),
  )
}

/// Handle note added response (success).
pub fn handle_note_added_ok(
  model: Model,
  note: TaskNote,
) -> #(Model, Effect(Msg)) {
  let updated = case model.member.notes.member_notes {
    Loaded(notes) -> [note, ..notes]
    _ -> [note]
  }

  let model =
    update_member_notes(model, fn(notes_state) {
      member_notes.Model(
        ..notes_state,
        member_note_in_flight: False,
        member_note_content: "",
        member_note_dialog_mode: dialog_mode.DialogClosed,
        member_notes: Loaded(updated),
      )
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(model, i18n_text.NoteAdded))
  #(model, toast_fx)
}

/// Handle note added response (error).
pub fn handle_note_added_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    let model =
      update_member_notes(model, fn(notes_state) {
        member_notes.Model(
          ..notes_state,
          member_note_in_flight: False,
          member_note_error: opt.Some(err.message),
        )
      })

    case model.member.notes.member_notes_task_id {
      opt.Some(task_id) -> #(
        model,
        api_tasks.list_task_notes(task_id, fn(result) {
          pool_msg(pool_messages.MemberNotesFetched(result))
        }),
      )
      opt.None -> #(model, effect.none())
    }
  })
}

// =============================================================================
// Task Dependencies Handlers
// =============================================================================

pub fn handle_dependencies_fetched_ok(
  model: Model,
  deps: List(TaskDependency),
) -> #(Model, Effect(Msg)) {
  #(
    update_member_dependencies(model, fn(dependencies) {
      member_dependencies.Model(
        ..dependencies,
        member_dependencies: Loaded(deps),
      )
    }),
    effect.none(),
  )
}

pub fn handle_dependencies_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member_dependencies(model, fn(dependencies) {
        member_dependencies.Model(
          ..dependencies,
          member_dependencies: Failed(err),
        )
      }),
      effect.none(),
    )
  })
}

pub fn handle_dependency_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.notes.member_notes_task_id {
    opt.None -> #(model, effect.none())
    opt.Some(task_id) ->
      case
        helpers_lookup.find_task_by_id(model.member.pool.member_tasks, task_id)
      {
        opt.None -> #(model, effect.none())
        opt.Some(task) -> {
          let model =
            update_member_dependencies(model, fn(dependencies) {
              member_dependencies.Model(
                ..dependencies,
                member_dependency_dialog_mode: dialog_mode.DialogCreate,
                member_dependency_search_query: "",
                member_dependency_candidates: Loading,
                member_dependency_selected_task_id: opt.None,
                member_dependency_add_error: opt.None,
              )
            })
          let filters =
            TaskFilters(
              status: opt.None,
              type_id: opt.None,
              capability_id: opt.None,
              q: opt.None,
              blocked: opt.None,
            )
          #(
            model,
            api_tasks.list_project_tasks(task.project_id, filters, fn(result) {
              pool_msg(pool_messages.MemberDependencyCandidatesFetched(result))
            }),
          )
        }
      }
  }
}

pub fn handle_dependency_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_member_dependencies(model, fn(dependencies) {
      member_dependencies.Model(
        ..dependencies,
        member_dependency_dialog_mode: dialog_mode.DialogClosed,
        member_dependency_search_query: "",
        member_dependency_candidates: NotAsked,
        member_dependency_selected_task_id: opt.None,
        member_dependency_add_error: opt.None,
      )
    }),
    effect.none(),
  )
}

pub fn handle_dependency_search_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_member_dependencies(model, fn(dependencies) {
      member_dependencies.Model(
        ..dependencies,
        member_dependency_search_query: value,
      )
    }),
    effect.none(),
  )
}

pub fn handle_dependency_candidates_fetched_ok(
  model: Model,
  tasks: List(Task),
) -> #(Model, Effect(Msg)) {
  #(
    update_member_dependencies(model, fn(dependencies) {
      member_dependencies.Model(
        ..dependencies,
        member_dependency_candidates: Loaded(tasks),
      )
    }),
    effect.none(),
  )
}

pub fn handle_dependency_candidates_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member_dependencies(model, fn(dependencies) {
        member_dependencies.Model(
          ..dependencies,
          member_dependency_candidates: Failed(err),
        )
      }),
      effect.none(),
    )
  })
}

pub fn handle_dependency_selected(
  model: Model,
  task_id: Int,
) -> #(Model, Effect(Msg)) {
  #(
    update_member_dependencies(model, fn(dependencies) {
      member_dependencies.Model(
        ..dependencies,
        member_dependency_selected_task_id: opt.Some(task_id),
      )
    }),
    effect.none(),
  )
}

pub fn handle_dependency_add_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.member.dependencies.member_dependency_add_in_flight {
    True -> #(model, effect.none())
    False -> submit_dependency_add(model)
  }
}

fn submit_dependency_add(model: Model) -> #(Model, Effect(Msg)) {
  case
    model.member.notes.member_notes_task_id,
    model.member.dependencies.member_dependency_selected_task_id
  {
    opt.Some(task_id), opt.Some(depends_on_task_id) ->
      submit_dependency_add_for_task(model, task_id, depends_on_task_id)
    _, _ -> #(model, effect.none())
  }
}

fn submit_dependency_add_for_task(
  model: Model,
  task_id: Int,
  depends_on_task_id: Int,
) -> #(Model, Effect(Msg)) {
  let model =
    update_member_dependencies(model, fn(dependencies) {
      member_dependencies.Model(
        ..dependencies,
        member_dependency_add_in_flight: True,
        member_dependency_add_error: opt.None,
      )
    })
  #(
    model,
    api_tasks.add_task_dependency(task_id, depends_on_task_id, fn(result) {
      pool_msg(pool_messages.MemberDependencyAdded(result))
    }),
  )
}

pub fn handle_dependency_added_ok(
  model: Model,
  dep: TaskDependency,
) -> #(Model, Effect(Msg)) {
  let updated = add_dependency_to_state(model, dep)
  let model =
    update_member_dependencies(updated, fn(dependencies) {
      member_dependencies.Model(
        ..dependencies,
        member_dependency_add_in_flight: False,
        member_dependency_dialog_mode: dialog_mode.DialogClosed,
        member_dependency_search_query: "",
        member_dependency_selected_task_id: opt.None,
        member_dependency_add_error: opt.None,
      )
    })
  #(model, effect.none())
}

pub fn handle_dependency_added_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member_dependencies(model, fn(dependencies) {
        member_dependencies.Model(
          ..dependencies,
          member_dependency_add_in_flight: False,
          member_dependency_add_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  })
}

pub fn handle_dependency_remove_clicked(
  model: Model,
  depends_on_task_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.member.dependencies.member_dependency_remove_in_flight {
    opt.Some(_) -> #(model, effect.none())
    opt.None ->
      case model.member.notes.member_notes_task_id {
        opt.None -> #(model, effect.none())
        opt.Some(task_id) -> #(
          update_member_dependencies(model, fn(dependencies) {
            member_dependencies.Model(
              ..dependencies,
              member_dependency_remove_in_flight: opt.Some(depends_on_task_id),
            )
          }),
          api_tasks.delete_task_dependency(
            task_id,
            depends_on_task_id,
            fn(result) {
              pool_msg(pool_messages.MemberDependencyRemoved(
                depends_on_task_id,
                result,
              ))
            },
          ),
        )
      }
  }
}

pub fn handle_dependency_removed_ok(
  model: Model,
  depends_on_task_id: Int,
) -> #(Model, Effect(Msg)) {
  let updated = remove_dependency_from_state(model, depends_on_task_id)
  #(
    update_member_dependencies(updated, fn(dependencies) {
      member_dependencies.Model(
        ..dependencies,
        member_dependency_remove_in_flight: opt.None,
      )
    }),
    effect.none(),
  )
}

pub fn handle_dependency_removed_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_member_dependencies(model, fn(dependencies) {
        member_dependencies.Model(
          ..dependencies,
          member_dependency_remove_in_flight: opt.None,
        )
      }),
      helpers_toast.toast_error(err.message),
    )
  })
}

fn add_dependency_to_state(model: Model, dep: TaskDependency) -> Model {
  case model.member.notes.member_notes_task_id {
    opt.None -> model
    opt.Some(task_id) ->
      update_member(model, fn(member) {
        let dependencies = member.dependencies
        let pool = member.pool

        let updated_deps = case dependencies.member_dependencies {
          Loaded(list) -> Loaded([dep, ..list])
          _ -> Loaded([dep])
        }
        let blocked_delta = case dep.status {
          Completed -> 0
          _ -> 1
        }
        let updated_tasks = case pool.member_tasks {
          Loaded(tasks) ->
            Loaded(
              list.map(tasks, fn(t) {
                case t.id == task_id {
                  True ->
                    Task(
                      ..t,
                      dependencies: [dep, ..t.dependencies],
                      blocked_count: t.blocked_count + blocked_delta,
                    )
                  False -> t
                }
              }),
            )
          _ -> pool.member_tasks
        }
        MemberModel(
          ..member,
          dependencies: member_dependencies.Model(
            ..dependencies,
            member_dependencies: updated_deps,
          ),
          pool: member_pool.Model(..pool, member_tasks: updated_tasks),
        )
      })
  }
}

fn remove_dependency_from_state(model: Model, depends_on_task_id: Int) -> Model {
  case model.member.notes.member_notes_task_id {
    opt.None -> model
    opt.Some(task_id) ->
      update_member(model, fn(member) {
        let dependencies = member.dependencies
        let pool = member.pool

        let #(updated_deps, blocked_delta) =
          remove_dependency_from_list(
            dependencies.member_dependencies,
            depends_on_task_id,
          )
        let updated_tasks = case pool.member_tasks {
          Loaded(tasks) ->
            Loaded(
              list.map(tasks, fn(t) {
                case t.id == task_id {
                  True ->
                    Task(
                      ..t,
                      dependencies: list.filter(t.dependencies, fn(dep) {
                        dep.depends_on_task_id != depends_on_task_id
                      }),
                      blocked_count: case t.blocked_count - blocked_delta {
                        n if n < 0 -> 0
                        n -> n
                      },
                    )
                  False -> t
                }
              }),
            )
          _ -> pool.member_tasks
        }
        MemberModel(
          ..member,
          dependencies: member_dependencies.Model(
            ..dependencies,
            member_dependencies: updated_deps,
          ),
          pool: member_pool.Model(..pool, member_tasks: updated_tasks),
        )
      })
  }
}

fn remove_dependency_from_list(
  deps_remote: Remote(List(TaskDependency)),
  depends_on_task_id: Int,
) -> #(Remote(List(TaskDependency)), Int) {
  case deps_remote {
    Loaded(deps) -> {
      let #(remaining, removed_status) =
        list.fold(deps, #([], opt.None), fn(acc, dep) {
          let #(items, status_opt) = acc
          case dep.depends_on_task_id == depends_on_task_id {
            True -> #(items, opt.Some(dep.status))
            False -> #([dep, ..items], status_opt)
          }
        })
      let blocked_delta = case removed_status {
        opt.Some(Completed) | opt.None -> 0
        opt.Some(_) -> 1
      }
      #(Loaded(list.reverse(remaining)), blocked_delta)
    }
    _ -> #(deps_remote, 0)
  }
}

fn update_member_pool(
  model: Model,
  f: fn(member_pool.Model) -> member_pool.Model,
) -> Model {
  update_member(model, fn(member) {
    let pool = member.pool
    MemberModel(..member, pool: f(pool))
  })
}

fn update_member_notes(
  model: Model,
  f: fn(member_notes.Model) -> member_notes.Model,
) -> Model {
  update_member(model, fn(member) {
    let notes = member.notes
    MemberModel(..member, notes: f(notes))
  })
}

fn update_member_dependencies(
  model: Model,
  f: fn(member_dependencies.Model) -> member_dependencies.Model,
) -> Model {
  update_member(model, fn(member) {
    let dependencies = member.dependencies
    MemberModel(..member, dependencies: f(dependencies))
  })
}
