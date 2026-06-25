//// Task mutation update flow for claim/release/complete operations.

import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/task.{type Task}
import domain/task/state as task_state
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/claimability
import scrumbringer_client/features/tasks/mutation_state
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/ui/toast

pub type MutationContext(parent_msg) {
  MutationContext(
    current_user_id: opt.Option(Int),
    on_task_claimed: fn(ApiResult(Task)) -> parent_msg,
    on_task_released: fn(ApiResult(Task)) -> parent_msg,
    on_task_completed: fn(ApiResult(Task)) -> parent_msg,
    on_task_deleted: fn(Int, ApiResult(Nil)) -> parent_msg,
  )
}

pub type DispatchContext(parent_msg) {
  DispatchContext(
    mutation_context: MutationContext(parent_msg),
    success_context: Context(parent_msg),
    error_context: ErrorContext(parent_msg),
  )
}

pub type Policy {
  NoPolicy
  RefreshMemberAfterSuccess
  RefreshMemberSilentlyAfterSuccess
  CheckAuthAfter(ApiError)
}

pub type Update(parent_msg) {
  Update(member_pool.Model, Effect(parent_msg), Policy)
}

pub type Success {
  Claimed
  Released
  Done
  Deleted
}

pub type ErrorLabels {
  ErrorLabels(
    task_not_found: String,
    task_already_claimed: String,
    task_blocked_by_dependencies: String,
    task_has_operational_history: String,
    task_version_conflict: String,
    task_mutation_rolled_back: String,
  )
}

pub type Context(parent_msg) {
  Context(
    task_claimed: String,
    task_released: String,
    task_completed: String,
    task_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_work_sessions_refetch: fn() -> Effect(parent_msg),
  )
}

pub type ErrorContext(parent_msg) {
  ErrorContext(
    labels: ErrorLabels,
    on_warning_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: DispatchContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberClaimClicked(task_id, version) ->
      handle_claim_clicked(model, task_id, version, context.mutation_context)
      |> without_policy

    pool_messages.MemberReleaseClicked(task_id, version) ->
      handle_release_clicked(model, task_id, version, context.mutation_context)
      |> without_policy

    pool_messages.MemberCompleteClicked(task_id, version) ->
      handle_complete_clicked(model, task_id, version, context.mutation_context)
      |> without_policy

    pool_messages.MemberDeleteTaskClicked(task_id) ->
      handle_delete_clicked(model, task_id, context.mutation_context)
      |> without_policy

    pool_messages.MemberTaskClaimed(Ok(task)) ->
      success(
        model,
        fn(model) { handle_task_claimed_ok(model, task) },
        Claimed,
        context.success_context,
      )

    pool_messages.MemberTaskReleased(Ok(task)) ->
      success(
        model,
        fn(model) { handle_task_released_ok(model, task) },
        Released,
        context.success_context,
      )

    pool_messages.MemberTaskDone(Ok(_)) ->
      success(model, handle_task_completed_ok, Done, context.success_context)

    pool_messages.MemberTaskDeleted(task_id, Ok(_)) ->
      success(
        model,
        fn(model) { handle_task_deleted_ok(model, task_id) },
        Deleted,
        context.success_context,
      )

    pool_messages.MemberTaskClaimed(Error(err))
    | pool_messages.MemberTaskReleased(Error(err))
    | pool_messages.MemberTaskDone(Error(err))
    | pool_messages.MemberTaskDeleted(_, Error(err)) ->
      mutation_error(model, err, context.error_context)

    _ -> opt.None
  }
}

fn without_policy(
  result: #(member_pool.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, NoPolicy))
}

fn success(
  model: member_pool.Model,
  transition: fn(member_pool.Model) -> #(member_pool.Model, Effect(parent_msg)),
  success: Success,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  let #(model, local_fx) = transition(model)
  opt.Some(Update(
    model,
    effect.batch([local_fx, success_effect(success, context)]),
    success_policy(success),
  ))
}

fn success_policy(success: Success) -> Policy {
  case success {
    Claimed | Released -> RefreshMemberSilentlyAfterSuccess
    Done | Deleted -> RefreshMemberAfterSuccess
  }
}

fn mutation_error(
  model: member_pool.Model,
  err: ApiError,
  context: ErrorContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  let #(model, local_fx) = handle_mutation_error(model)
  opt.Some(Update(
    model,
    effect.batch([local_fx, error_effect(err, context)]),
    CheckAuthAfter(err),
  ))
}

/// Handle claim button click with optimistic update.
/// Immediately marks task as claimed locally, sends API request.
fn handle_claim_clicked(
  model: member_pool.Model,
  task_id: Int,
  version: Int,
  context: MutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False ->
      case helpers_lookup.find_task_by_id(model.member_tasks, task_id) {
        opt.Some(task) ->
          case claimability.can_claim(task) {
            True -> submit_claim(model, task_id, version, context)
            False -> #(model, effect.none())
          }
        _ -> #(model, effect.none())
      }
  }
}

/// Handle drag/drop claim without changing the current task list optimistically.
pub fn handle_claim_dropped(
  model: member_pool.Model,
  task_id: Int,
  context: MutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case
    helpers_lookup.find_task_by_id(model.member_tasks, task_id),
    model.member_task_mutation_in_flight
  {
    opt.Some(task), False ->
      case claimability.can_claim(task) {
        True -> #(
          mutation_state.start_dropped_claim(model),
          task_operations_api.claim_task(
            task_id,
            task.version,
            context.on_task_claimed,
          ),
        )
        False -> #(model, effect.none())
      }
    opt.Some(_), _ -> #(model, effect.none())
    opt.None, _ -> #(model, effect.none())
  }
}

fn submit_claim(
  model: member_pool.Model,
  task_id: Int,
  version: Int,
  context: MutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    mutation_state.start_claim(model, task_id, context.current_user_id),
    task_operations_api.claim_task(task_id, version, context.on_task_claimed),
  )
}

/// Handle release button click with optimistic update.
/// Immediately marks task as available locally, sends API request.
fn handle_release_clicked(
  model: member_pool.Model,
  task_id: Int,
  version: Int,
  context: MutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> #(
      mutation_state.start_release(model, task_id),
      task_operations_api.release_task(
        task_id,
        version,
        context.on_task_released,
      ),
    )
  }
}

/// Handle complete button click with optimistic update.
/// Immediately marks task as completed locally, sends API request.
fn handle_complete_clicked(
  model: member_pool.Model,
  task_id: Int,
  version: Int,
  context: MutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> #(
      mutation_state.start_complete(model, task_id, context.current_user_id),
      task_operations_api.complete_task(
        task_id,
        version,
        context.on_task_completed,
      ),
    )
  }
}

fn handle_delete_clicked(
  model: member_pool.Model,
  task_id: Int,
  context: MutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False ->
      case helpers_lookup.find_task_by_id(model.member_tasks, task_id) {
        opt.Some(task) ->
          case can_delete_without_visible_history(task) {
            True -> submit_delete(model, task_id, context)
            False -> #(model, effect.none())
          }
        opt.None -> #(model, effect.none())
      }
  }
}

fn submit_delete(
  model: member_pool.Model,
  task_id: Int,
  context: MutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    mutation_state.start_delete(model, task_id),
    task_operations_api.delete_task(task_id, fn(result) {
      context.on_task_deleted(task_id, result)
    }),
  )
}

fn can_delete_without_visible_history(task: Task) -> Bool {
  case task.state, task.blocked_count {
    task_state.Available, 0 -> True
    _, _ -> False
  }
}

/// Clear optimistic state after successful mutation.
fn clear_optimistic_state(model: member_pool.Model) -> member_pool.Model {
  mutation_state.clear(model)
}

/// Handle successful task claim.
/// Clears snapshot and refreshes from server for authoritative state.
fn handle_task_claimed_ok(
  model: member_pool.Model,
  task: Task,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(mutation_state.confirm_task(model, task), effect.none())
}

/// Handle successful task release.
/// Clears snapshot and refreshes from server for authoritative state.
fn handle_task_released_ok(
  model: member_pool.Model,
  task: Task,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(mutation_state.confirm_task(model, task), effect.none())
}

/// Handle successful task completion.
/// Clears snapshot and refreshes from server for authoritative state.
fn handle_task_completed_ok(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(clear_optimistic_state(model), effect.none())
}

fn handle_task_deleted_ok(
  model: member_pool.Model,
  _task_id: Int,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..clear_optimistic_state(model),
      member_task_show_editing: False,
    ),
    effect.none(),
  )
}

/// Handle mutation error.
/// Restores snapshot and clears optimistic state.
fn handle_mutation_error(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(mutation_state.restore_and_clear(model), effect.none())
}

fn success_effect(
  success: Success,
  context: Context(parent_msg),
) -> Effect(parent_msg) {
  let toast_fx = context.on_success_toast(success_message(success, context))

  case should_refetch_work_sessions(success) {
    True -> effect.batch([toast_fx, context.on_work_sessions_refetch()])
    False -> toast_fx
  }
}

pub fn should_refetch_work_sessions(success: Success) -> Bool {
  case success {
    Claimed -> False
    Released | Done | Deleted -> True
  }
}

fn success_message(success: Success, context: Context(parent_msg)) -> String {
  case success {
    Claimed -> context.task_claimed
    Released -> context.task_released
    Done -> context.task_completed
    Deleted -> context.task_deleted
  }
}

fn error_effect(
  err: ApiError,
  context: ErrorContext(parent_msg),
) -> Effect(parent_msg) {
  let #(message, variant) = error_feedback(err, context.labels)

  case variant {
    toast.Warning -> context.on_warning_toast(message)
    toast.Error -> context.on_error_toast(message)
    _ -> context.on_error_toast(message)
  }
}

pub fn error_feedback(
  err: ApiError,
  labels: ErrorLabels,
) -> #(String, toast.ToastVariant) {
  case err.status {
    404 -> #(labels.task_not_found, toast.Warning)
    409 -> #(conflict_message(err, labels), toast.Warning)
    422 -> #(unprocessable_message(err, labels), toast.Warning)
    _ -> #(labels.task_mutation_rolled_back <> ": " <> err.message, toast.Error)
  }
}

fn conflict_message(err: ApiError, labels: ErrorLabels) -> String {
  case
    string.contains(err.code, "BLOCKED"),
    string.contains(err.code, "CLAIMED"),
    string.contains(err.code, "OPERATIONAL_HISTORY")
  {
    True, _, _ -> labels.task_blocked_by_dependencies
    _, True, _ -> labels.task_already_claimed
    _, _, True -> labels.task_has_operational_history
    False, False, False -> labels.task_version_conflict
  }
}

fn unprocessable_message(err: ApiError, labels: ErrorLabels) -> String {
  case string.contains(err.code, "VERSION") {
    True -> labels.task_version_conflict
    False -> err.message
  }
}
