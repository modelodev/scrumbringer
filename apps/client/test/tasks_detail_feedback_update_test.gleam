import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/tasks/detail_update
import scrumbringer_client/ui/toast

fn success_context() -> detail_update.SuccessContext(Nil) {
  detail_update.SuccessContext(
    task_updated: "Task updated",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_context() -> detail_update.ErrorContext(Nil) {
  detail_update.ErrorContext(
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn sample_task() -> Task {
  let state = task_state.Available
  Task(
    id: 42,
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

pub fn detail_update_ok_replaces_task_and_emits_success_toast_test() {
  let updated = Task(..sample_task(), title: "Updated", version: 4)
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: remote.Loaded([sample_task()]),
      member_task_detail_editing: True,
      member_task_detail_edit_in_flight: True,
      member_task_detail_edit_error: Some("old"),
    )

  let #(next, fx) = detail_update.updated_ok(model, updated, success_context())

  let assert True = next.member_tasks == remote.Loaded([updated])
  let assert False = next.member_task_detail_editing
  let assert False = next.member_task_detail_edit_in_flight
  let assert None = next.member_task_detail_edit_error
  let assert True = fx != effect.none()
}

pub fn detail_update_error_sets_local_error_and_emits_feedback_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_detail_edit_in_flight: True,
      member_task_detail_edit_error: None,
    )

  let #(next, fx) = detail_update.updated_error(model, err, error_context())

  let assert False = next.member_task_detail_edit_in_flight
  let assert Some("boom") = next.member_task_detail_edit_error
  let assert True = fx != effect.none()
}

pub fn detail_update_error_409_is_warning_test() {
  let #(message, variant) =
    detail_update.error_feedback(ApiError(
      status: 409,
      code: "VERSION_CONFLICT",
      message: "stale",
    ))

  let assert "stale" = message
  let assert toast.Warning = variant
}

pub fn detail_update_error_500_is_error_test() {
  let #(message, variant) =
    detail_update.error_feedback(ApiError(
      status: 500,
      code: "SERVER_ERROR",
      message: "boom",
    ))

  let assert "boom" = message
  let assert toast.Error = variant
}
