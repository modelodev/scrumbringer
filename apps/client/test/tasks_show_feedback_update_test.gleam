import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/show_update
import scrumbringer_client/ui/toast

fn success_context() -> show_update.SuccessContext(Nil) {
  show_update.SuccessContext(
    task_updated: "Task updated",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_context() -> show_update.ErrorContext(Nil) {
  show_update.ErrorContext(
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_error_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn open_context() -> show_update.Context(Nil) {
  show_update.Context(
    on_notes_fetched: fn(_result) { Nil },
    on_dependencies_fetched: fn(_result) { Nil },
    on_activity_fetched: fn(_result) { Nil },
  )
}

fn edit_context() -> show_update.EditContext(Nil) {
  show_update.EditContext(
    current_task: Some(sample_task()),
    can_edit: True,
    on_task_updated: fn(_result) { Nil },
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1-5",
  )
}

fn dispatch_context() -> show_update.DispatchContext(Nil) {
  show_update.DispatchContext(
    open_context: open_context(),
    edit_context: edit_context(),
    success_context: success_context(),
    error_context: error_context(),
  )
}

fn show_model(pool: member_pool.Model) -> show_update.Model {
  show_update.Model(
    pool: pool,
    notes: member_notes.default_model(),
    dependencies: member_dependencies.default_model(),
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
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

pub fn show_update_ok_replaces_task_and_emits_success_toast_test() {
  let updated = Task(..sample_task(), title: "Updated", version: 4)
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: remote.Loaded([sample_task()]),
      member_task_show_editing: True,
      member_task_show_edit_in_flight: True,
      member_task_show_edit_error: Some("old"),
    )

  let assert Some(show_update.Update(next, fx, policy)) =
    show_update.try_update(
      show_model(model),
      pool_messages.MemberTaskUpdated(Ok(updated)),
      dispatch_context(),
    )

  let assert True = next.pool.member_tasks == remote.Loaded([updated])
  let assert False = next.pool.member_task_show_editing
  let assert False = next.pool.member_task_show_edit_in_flight
  let assert None = next.pool.member_task_show_edit_error
  let assert show_update.NoAuthCheck = policy
  let assert True = fx != effect.none()
}

pub fn show_update_error_sets_local_error_and_emits_feedback_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_show_edit_in_flight: True,
      member_task_show_edit_error: None,
    )

  let assert Some(show_update.Update(next, fx, policy)) =
    show_update.try_update(
      show_model(model),
      pool_messages.MemberTaskUpdated(Error(err)),
      dispatch_context(),
    )

  let assert False = next.pool.member_task_show_edit_in_flight
  let assert Some("boom") = next.pool.member_task_show_edit_error
  let assert show_update.CheckAuthAfter(auth_err) = policy
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}

pub fn show_update_error_409_is_warning_test() {
  let #(message, variant) =
    show_update.error_feedback(ApiError(
      status: 409,
      code: "VERSION_CONFLICT",
      message: "stale",
    ))

  let assert "stale" = message
  let assert toast.Warning = variant
}

pub fn show_update_error_500_is_error_test() {
  let #(message, variant) =
    show_update.error_feedback(ApiError(
      status: 500,
      code: "SERVER_ERROR",
      message: "boom",
    ))

  let assert "boom" = message
  let assert toast.Error = variant
}
