import gleam/option.{None, Some}
import lustre/effect
import support/domain_fixtures

import domain/api_error.{ApiError}
import domain/remote
import domain/task.{Task, with_state}
import domain/task/state as task_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/mutation_update
import scrumbringer_client/features/tasks/task_action
import scrumbringer_client/ui/toast

fn mutation_context() {
  mutation_update.MutationContext(
    current_user_id: Some(7),
    on_task_claimed: fn(_result) { Nil },
    on_task_released: fn(_result) { Nil },
    on_task_closed: fn(_result) { Nil },
    on_task_resolved_for_action: fn(_action, _result) { Nil },
    on_task_deleted: fn(_task_id, _result) { Nil },
  )
}

fn success_context() {
  mutation_update.Context(
    task_claimed: "Claimed",
    task_released: "Released",
    task_closed: "Closed",
    task_deleted: "Deleted",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_work_sessions_refetch: fn() { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_context() {
  mutation_update.ErrorContext(
    labels: labels(),
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn dispatch_context() {
  mutation_update.DispatchContext(
    mutation_context: mutation_context(),
    success_context: success_context(),
    error_context: error_context(),
  )
}

fn sample_task(id, state) {
  Task(
    ..domain_fixtures.task(id, "Prepare release", 1),
    description: Some("Review checklist."),
    priority: 2,
    state: state,
    created_at: "2026-03-20T14:00:00Z",
    version: 3,
  )
}

fn available_task() {
  sample_task(42, task_state.Available)
}

fn blocked_available_task() {
  Task(..available_task(), blocked_count: 1)
}

fn taken_task() {
  sample_task(
    42,
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-03-20T15:00:00Z",
      mode: task_state.Taken,
    ),
  )
}

fn pool_with_tasks(tasks) {
  member_pool.Model(
    ..member_pool.default_model(),
    member_tasks: remote.Loaded(tasks),
  )
}

pub fn try_update_claim_clicked_sets_local_policy_test() {
  let task = available_task()

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberClaimClicked(task_action.Resolved(42, 3)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert Some([_task]) = next.member_tasks_snapshot
  let assert True = next.member_tasks == remote.Loaded([claimed_task(task, 7)])
  let assert True = fx != effect.none()
}

pub fn try_update_release_success_requests_silent_member_refresh_test() {
  let model =
    member_pool.Model(
      ..pool_with_tasks([available_task()]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
      member_tasks_snapshot: Some([]),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      model,
      pool_messages.MemberTaskReleased(Ok(available_task())),
      dispatch_context(),
    )

  let assert mutation_update.RefreshMemberSilentlyAfterSuccess = policy
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = next.member_tasks == remote.Loaded([available_task()])
  let assert True = fx != effect.none()
}

pub fn try_update_error_checks_auth_after_rollback_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")
  let original = available_task()
  let model =
    member_pool.Model(
      ..pool_with_tasks([claimed_task(original, 7)]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
      member_tasks_snapshot: Some([original]),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      model,
      pool_messages.MemberTaskClosed(Error(err)),
      dispatch_context(),
    )
  let assert mutation_update.CheckAuthAfter(auth_err) = policy

  let assert True = auth_err == err
  let assert True = next.member_tasks == remote.Loaded([original])
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx != effect.none()
}

pub fn try_update_ignores_non_mutation_messages_test() {
  let assert None =
    mutation_update.try_update(
      pool_with_tasks([]),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      dispatch_context(),
    )
}

pub fn local_claim_clicked_blocked_task_does_not_submit_test() {
  let task = blocked_available_task()

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberClaimClicked(task_action.Resolved(42, 3)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx == effect.none()
}

pub fn local_claim_clicked_applies_optimistic_claim_test() {
  let task = available_task()

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberClaimClicked(task_action.Resolved(42, 3)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert Some([snapshot_task]) = next.member_tasks_snapshot
  let assert True = snapshot_task == task
  let assert True = next.member_tasks == remote.Loaded([claimed_task(task, 7)])
  let assert True = fx != effect.none()
}

pub fn local_claim_dropped_marks_in_flight_without_optimistic_claim_test() {
  let task = available_task()

  let #(next, fx) =
    mutation_update.handle_claim_dropped(
      pool_with_tasks([task]),
      42,
      mutation_context(),
    )

  let assert True = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = next.member_tasks == remote.Loaded([task])
  let assert True = fx != effect.none()
}

pub fn local_claim_dropped_blocked_task_does_not_submit_test() {
  let task = blocked_available_task()

  let #(next, fx) =
    mutation_update.handle_claim_dropped(
      pool_with_tasks([task]),
      42,
      mutation_context(),
    )

  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx == effect.none()
}

pub fn local_release_clicked_applies_optimistic_release_test() {
  let task = taken_task()

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberReleaseClicked(task_action.Resolved(42, 3)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let expected = available_task()
  let assert True = next.member_tasks == remote.Loaded([expected])
  let assert True = next.member_task_mutation_in_flight
  let assert True = fx != effect.none()
}

pub fn release_needs_resolution_uses_cached_task_version_test() {
  let task = Task(..taken_task(), version: 9)

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberReleaseClicked(task_action.NeedsResolution(42)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let expected = Task(..available_task(), version: 9)
  let assert True = next.member_tasks == remote.Loaded([expected])
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert True = fx != effect.none()
}

pub fn local_close_clicked_applies_optimistic_close_test() {
  let task = taken_task()

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberCloseClicked(task_action.Resolved(42, 3)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let expected =
    sample_task(42, task_state.Closed(task_state.ClosedByClaimant, "", 7))
  let assert True = next.member_tasks == remote.Loaded([expected])
  let assert True = next.member_task_mutation_in_flight
  let assert True = fx != effect.none()
}

pub fn close_needs_resolution_uses_cached_task_version_test() {
  let task = Task(..taken_task(), version: 9)

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberCloseClicked(task_action.NeedsResolution(42)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let expected =
    sample_task(42, task_state.Closed(task_state.ClosedByClaimant, "", 7))
  let assert True =
    next.member_tasks == remote.Loaded([Task(..expected, version: 9)])
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert True = fx != effect.none()
}

pub fn close_needs_resolution_fetches_missing_task_before_close_test() {
  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([]),
      pool_messages.MemberCloseClicked(task_action.NeedsResolution(42)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = next.member_tasks == remote.Loaded([])
  let assert True = fx != effect.none()
}

pub fn resolved_close_action_closes_with_resolved_version_test() {
  let task = Task(..taken_task(), version: 11)
  let resolving =
    member_pool.Model(
      ..pool_with_tasks([]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      resolving,
      pool_messages.MemberTaskResolvedForAction(task_action.Close, Ok(task)),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert True = next.member_tasks == remote.Loaded([])
  let assert True = fx != effect.none()
}

pub fn task_action_resolution_error_checks_auth_after_clear_test() {
  let err = ApiError(status: 404, code: "NOT_FOUND", message: "missing")
  let resolving =
    member_pool.Model(
      ..pool_with_tasks([]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      resolving,
      pool_messages.MemberTaskResolvedForAction(task_action.Close, Error(err)),
      dispatch_context(),
    )
  let assert mutation_update.CheckAuthAfter(auth_err) = policy

  let assert True = auth_err == err
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx != effect.none()
}

pub fn local_delete_clicked_available_task_applies_optimistic_delete_test() {
  let task = available_task()

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberDeleteTaskClicked(42),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_tasks == remote.Loaded([])
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert Some([snapshot_task]) = next.member_tasks_snapshot
  let assert True = snapshot_task == task
  let assert True = fx != effect.none()
}

pub fn local_delete_clicked_claimed_task_does_not_submit_test() {
  let task = taken_task()

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberDeleteTaskClicked(42),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_tasks == remote.Loaded([task])
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx == effect.none()
}

pub fn local_delete_clicked_blocked_task_does_not_submit_test() {
  let task = blocked_available_task()

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberDeleteTaskClicked(42),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_tasks == remote.Loaded([task])
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx == effect.none()
}

pub fn local_task_claimed_ok_reconciles_payload_and_clears_optimistic_state_test() {
  let task = available_task()
  let claimed = claimed_task(task, 7)
  let model =
    member_pool.Model(
      ..pool_with_tasks([task]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
      member_tasks_snapshot: Some([]),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      model,
      pool_messages.MemberTaskClaimed(Ok(claimed)),
      dispatch_context(),
    )

  let assert mutation_update.RefreshMemberSilentlyAfterSuccess = policy
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = next.member_tasks == remote.Loaded([claimed])
  let assert True = fx != effect.none()
}

pub fn mutation_success_claim_does_not_refetch_work_sessions_test() {
  let assert False =
    mutation_update.should_refetch_work_sessions(mutation_update.Claimed)
}

pub fn mutation_success_release_refetches_work_sessions_test() {
  let assert True =
    mutation_update.should_refetch_work_sessions(mutation_update.Released)
}

pub fn mutation_success_close_refetches_work_sessions_test() {
  let assert True =
    mutation_update.should_refetch_work_sessions(mutation_update.Closed)
}

pub fn mutation_error_404_uses_not_found_warning_test() {
  let #(message, variant) =
    mutation_update.error_feedback(
      ApiError(status: 404, code: "TASK_NOT_FOUND", message: "missing"),
      labels(),
    )

  let assert "Task not found" = message
  let assert toast.Warning = variant
}

pub fn mutation_error_409_claimed_uses_claimed_warning_test() {
  let #(message, variant) =
    mutation_update.error_feedback(
      ApiError(status: 409, code: "TASK_ALREADY_CLAIMED", message: "claimed"),
      labels(),
    )

  let assert "Task already claimed" = message
  let assert toast.Warning = variant
}

pub fn mutation_error_409_blocked_uses_blocked_warning_test() {
  let #(message, variant) =
    mutation_update.error_feedback(
      ApiError(status: 409, code: "CONFLICT_BLOCKED", message: "blocked"),
      labels(),
    )

  let assert "Blocked by dependencies" = message
  let assert toast.Warning = variant
}

pub fn mutation_error_409_card_not_active_uses_server_message_test() {
  let #(message, variant) =
    mutation_update.error_feedback(
      ApiError(
        status: 409,
        code: "TASK_CARD_NOT_ACTIVE",
        message: "Task card is not active",
      ),
      labels(),
    )

  let assert "Task card is not active" = message
  let assert toast.Warning = variant
}

pub fn mutation_error_409_other_uses_version_warning_test() {
  let #(message, variant) =
    mutation_update.error_feedback(
      ApiError(status: 409, code: "VERSION_CONFLICT", message: "version"),
      labels(),
    )

  let assert "Task version conflict" = message
  let assert toast.Warning = variant
}

pub fn mutation_error_422_version_uses_version_warning_test() {
  let #(message, variant) =
    mutation_update.error_feedback(
      ApiError(status: 422, code: "STALE_VERSION", message: "stale"),
      labels(),
    )

  let assert "Task version conflict" = message
  let assert toast.Warning = variant
}

pub fn mutation_error_422_non_version_keeps_backend_message_test() {
  let #(message, variant) =
    mutation_update.error_feedback(
      ApiError(status: 422, code: "INVALID_STATE", message: "invalid state"),
      labels(),
    )

  let assert "invalid state" = message
  let assert toast.Warning = variant
}

pub fn mutation_error_generic_uses_rollback_error_test() {
  let #(message, variant) =
    mutation_update.error_feedback(
      ApiError(status: 500, code: "SERVER_ERROR", message: "boom"),
      labels(),
    )

  let assert "Rolled back: boom" = message
  let assert toast.Error = variant
}

pub fn local_mutation_error_restores_snapshot_and_clears_state_test() {
  let original = available_task()
  let optimistic = claimed_task(original, 7)
  let model =
    member_pool.Model(
      ..pool_with_tasks([optimistic]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
      member_tasks_snapshot: Some([original]),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      model,
      pool_messages.MemberTaskClaimed(
        Error(ApiError(status: 500, code: "ERR", message: "boom")),
      ),
      dispatch_context(),
    )

  let assert mutation_update.CheckAuthAfter(_) = policy
  let assert True = next.member_tasks == remote.Loaded([original])
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx != effect.none()
}

fn labels() {
  mutation_update.ErrorLabels(
    task_not_found: "Task not found",
    task_already_claimed: "Task already claimed",
    task_blocked_by_dependencies: "Blocked by dependencies",
    task_has_operational_history: "Has operational history",
    task_version_conflict: "Task version conflict",
    task_mutation_rolled_back: "Rolled back",
  )
}

fn claimed_task(task, user_id) {
  with_state(
    task,
    task_state.Claimed(
      claimed_by: user_id,
      claimed_at: "",
      mode: task_state.Taken,
    ),
  )
}
