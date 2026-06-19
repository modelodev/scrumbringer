import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote
import domain/task.{type Task, Task, with_state}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/mutation_update
import scrumbringer_client/ui/toast

fn mutation_context() -> mutation_update.MutationContext(Nil) {
  mutation_update.MutationContext(
    current_user_id: Some(7),
    on_task_claimed: fn(_result) { Nil },
    on_task_released: fn(_result) { Nil },
    on_task_completed: fn(_result) { Nil },
  )
}

fn success_context() -> mutation_update.Context(Nil) {
  mutation_update.Context(
    task_claimed: "Claimed",
    task_released: "Released",
    task_completed: "Completed",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_work_sessions_refetch: fn() { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_context() -> mutation_update.ErrorContext(Nil) {
  mutation_update.ErrorContext(
    labels: labels(),
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn dispatch_context() -> mutation_update.DispatchContext(Nil) {
  mutation_update.DispatchContext(
    mutation_context: mutation_context(),
    success_context: success_context(),
    error_context: error_context(),
  )
}

fn sample_task(id: Int, state: task_state.TaskState) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Review checklist."),
    priority: 2,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    milestone_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn pool_with_tasks(tasks: List(Task)) -> member_pool.Model {
  member_pool.Model(
    ..member_pool.default_model(),
    member_tasks: remote.Loaded(tasks),
  )
}

pub fn try_update_claim_clicked_sets_local_policy_test() {
  let task = sample_task(42, task_state.Available)

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberClaimClicked(42, 3),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert Some([task]) = next.member_tasks_snapshot
  let assert True = next.member_tasks == remote.Loaded([claimed_task(task, 7)])
  let assert True = fx != effect.none()
}

pub fn try_update_success_requests_member_refresh_test() {
  let model =
    member_pool.Model(
      ..pool_with_tasks([sample_task(42, task_state.Available)]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
      member_tasks_snapshot: Some([]),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      model,
      pool_messages.MemberTaskReleased(
        Ok(sample_task(42, task_state.Available)),
      ),
      dispatch_context(),
    )

  let assert mutation_update.RefreshMemberAfterSuccess = policy
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx != effect.none()
}

pub fn try_update_error_checks_auth_after_rollback_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")
  let original = sample_task(42, task_state.Available)
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
      pool_messages.MemberTaskCompleted(Error(err)),
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
      pool_messages.MemberPoolFiltersToggled,
      dispatch_context(),
    )
}

pub fn local_claim_clicked_blocked_task_does_not_submit_test() {
  let task = Task(..sample_task(42, task_state.Available), blocked_count: 1)

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberClaimClicked(42, 3),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
  let assert True = fx == effect.none()
}

pub fn local_claim_clicked_applies_optimistic_claim_test() {
  let task = sample_task(42, task_state.Available)

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberClaimClicked(42, 3),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let assert True = next.member_task_mutation_in_flight
  let assert Some(42) = next.member_task_mutation_task_id
  let assert Some([task]) = next.member_tasks_snapshot
  let assert True = next.member_tasks == remote.Loaded([claimed_task(task, 7)])
  let assert True = fx != effect.none()
}

pub fn local_claim_dropped_marks_in_flight_without_optimistic_claim_test() {
  let task = sample_task(42, task_state.Available)

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
  let task = Task(..sample_task(42, task_state.Available), blocked_count: 1)

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
  let task =
    sample_task(
      42,
      task_state.Claimed(
        claimed_by: 7,
        claimed_at: "2026-03-20T15:00:00Z",
        mode: task_status.Taken,
      ),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberReleaseClicked(42, 3),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let expected = sample_task(42, task_state.Available)
  let assert True = next.member_tasks == remote.Loaded([expected])
  let assert True = next.member_task_mutation_in_flight
  let assert True = fx != effect.none()
}

pub fn local_complete_clicked_applies_optimistic_complete_test() {
  let task =
    sample_task(
      42,
      task_state.Claimed(
        claimed_by: 7,
        claimed_at: "2026-03-20T15:00:00Z",
        mode: task_status.Taken,
      ),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      pool_with_tasks([task]),
      pool_messages.MemberCompleteClicked(42, 3),
      dispatch_context(),
    )

  let assert mutation_update.NoPolicy = policy
  let expected = sample_task(42, task_state.Completed(completed_at: ""))
  let assert True = next.member_tasks == remote.Loaded([expected])
  let assert True = next.member_task_mutation_in_flight
  let assert True = fx != effect.none()
}

pub fn local_task_claimed_ok_clears_optimistic_state_test() {
  let model =
    member_pool.Model(
      ..pool_with_tasks([sample_task(42, task_state.Available)]),
      member_task_mutation_in_flight: True,
      member_task_mutation_task_id: Some(42),
      member_tasks_snapshot: Some([]),
    )

  let assert Some(mutation_update.Update(next, fx, policy)) =
    mutation_update.try_update(
      model,
      pool_messages.MemberTaskClaimed(Ok(sample_task(42, task_state.Available))),
      dispatch_context(),
    )

  let assert mutation_update.RefreshMemberAfterSuccess = policy
  let assert False = next.member_task_mutation_in_flight
  let assert None = next.member_task_mutation_task_id
  let assert None = next.member_tasks_snapshot
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

pub fn mutation_success_complete_refetches_work_sessions_test() {
  let assert True =
    mutation_update.should_refetch_work_sessions(mutation_update.Completed)
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
  let original = sample_task(42, task_state.Available)
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

fn labels() -> mutation_update.ErrorLabels {
  mutation_update.ErrorLabels(
    task_not_found: "Task not found",
    task_already_claimed: "Task already claimed",
    task_blocked_by_dependencies: "Blocked by dependencies",
    task_version_conflict: "Task version conflict",
    task_mutation_rolled_back: "Rolled back",
  )
}

fn claimed_task(task: Task, user_id: Int) -> Task {
  with_state(
    task,
    task_state.Claimed(
      claimed_by: user_id,
      claimed_at: "",
      mode: task_status.Taken,
    ),
  )
}
