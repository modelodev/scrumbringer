import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{type ApiError, ApiError}
import domain/metrics.{type TaskModalMetrics, TaskModalMetrics}
import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/detail_update
import scrumbringer_client/ui/task_tabs

fn sample_metrics() -> TaskModalMetrics {
  TaskModalMetrics(
    claim_count: 1,
    release_count: 0,
    unique_executors: 1,
    first_claim_at: None,
    current_state_duration_s: 10,
    pool_lifetime_s: 20,
    session_count: 1,
    total_work_time_s: 30,
  )
}

fn sample_error() -> ApiError {
  ApiError(status: 500, code: "ERR", message: "boom")
}

fn edit_context(current_task, can_edit) -> detail_update.EditContext(Nil) {
  detail_update.EditContext(
    current_task: current_task,
    can_edit: can_edit,
    on_task_updated: fn(_result) { Nil },
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1-5",
  )
}

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

fn detail_context() -> detail_update.Context(Nil) {
  detail_update.Context(
    on_notes_fetched: fn(_result) { Nil },
    on_dependencies_fetched: fn(_result) { Nil },
    on_metrics_fetched: fn(_result) { Nil },
  )
}

fn dispatch_context() -> detail_update.DispatchContext(Nil) {
  dispatch_context_with_edit(Some(sample_task()), True)
}

fn dispatch_context_with_edit(
  current_task,
  can_edit,
) -> detail_update.DispatchContext(Nil) {
  detail_update.DispatchContext(
    open_context: detail_context(),
    edit_context: edit_context(current_task, can_edit),
    success_context: success_context(),
    error_context: error_context(),
  )
}

fn apply_pool_update(model, message, context) {
  let assert Some(detail_update.Update(next, fx, policy)) =
    detail_update.try_update(detail_model(model), message, context)
  #(next.pool, fx, policy)
}

fn detail_model(pool: member_pool.Model) -> detail_update.Model {
  detail_update.Model(
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

pub fn try_update_tab_clicked_sets_tab_without_auth_test() {
  let model = detail_model(member_pool.default_model())

  let assert Some(detail_update.Update(next, fx, auth_policy)) =
    detail_update.try_update(
      model,
      pool_messages.MemberTaskDetailTabClicked(task_tabs.MetricsTab),
      dispatch_context(),
    )

  let assert task_tabs.MetricsTab = next.pool.member_task_detail_tab
  let assert True = next.notes == model.notes
  let assert True = next.dependencies == model.dependencies
  let assert detail_update.NoAuthCheck = auth_policy
  let assert True = fx == effect.none()
}

pub fn try_update_error_checks_auth_after_local_feedback_test() {
  let err = sample_error()
  let model =
    detail_model(
      member_pool.Model(
        ..member_pool.default_model(),
        member_task_detail_edit_in_flight: True,
        member_task_detail_edit_error: None,
      ),
    )

  let assert Some(detail_update.Update(next, fx, auth_policy)) =
    detail_update.try_update(
      model,
      pool_messages.MemberTaskUpdated(Error(err)),
      dispatch_context(),
    )
  let assert detail_update.CheckAuthAfter(auth_err) = auth_policy

  let assert False = next.pool.member_task_detail_edit_in_flight
  let assert Some("boom") = next.pool.member_task_detail_edit_error
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}

pub fn try_update_ignores_non_detail_messages_test() {
  let assert None =
    detail_update.try_update(
      detail_model(member_pool.default_model()),
      pool_messages.MemberPoolFiltersToggled,
      dispatch_context(),
    )
}

pub fn local_task_detail_tab_clicked_sets_tab_test() {
  let #(next, fx, policy) =
    apply_pool_update(
      member_pool.default_model(),
      pool_messages.MemberTaskDetailTabClicked(task_tabs.MetricsTab),
      dispatch_context(),
    )

  let assert task_tabs.MetricsTab = next.member_task_detail_tab
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_detail_edit_started_sets_edit_values_when_allowed_test() {
  let #(next, fx, policy) =
    apply_pool_update(
      member_pool.default_model(),
      pool_messages.MemberTaskDetailEditStarted,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert True = next.member_task_detail_editing
  let assert "Prepare release" = next.member_task_detail_edit_title
  let assert "Review checklist." = next.member_task_detail_edit_description
  let assert None = next.member_task_detail_edit_error
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_detail_edit_started_ignores_disallowed_task_test() {
  let #(next, fx, policy) =
    apply_pool_update(
      member_pool.default_model(),
      pool_messages.MemberTaskDetailEditStarted,
      dispatch_context_with_edit(Some(sample_task()), False),
    )

  let assert False = next.member_task_detail_editing
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_detail_edit_cancelled_restores_task_values_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_detail_editing: True,
      member_task_detail_edit_title: "Changed",
      member_task_detail_edit_description: "Changed description",
      member_task_detail_edit_in_flight: True,
      member_task_detail_edit_error: Some("error"),
    )

  let #(next, fx, policy) =
    apply_pool_update(
      model,
      pool_messages.MemberTaskDetailEditCancelled,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert False = next.member_task_detail_editing
  let assert "Prepare release" = next.member_task_detail_edit_title
  let assert "Review checklist." = next.member_task_detail_edit_description
  let assert False = next.member_task_detail_edit_in_flight
  let assert None = next.member_task_detail_edit_error
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_detail_edit_title_changed_clears_error_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_detail_edit_title: "Old",
      member_task_detail_edit_error: Some("error"),
    )

  let #(next, fx, policy) =
    apply_pool_update(
      model,
      pool_messages.MemberTaskDetailEditTitleChanged("New"),
      dispatch_context(),
    )

  let assert "New" = next.member_task_detail_edit_title
  let assert None = next.member_task_detail_edit_error
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_detail_edit_submitted_blank_title_sets_error_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_detail_edit_title: "   ",
      member_task_detail_edit_description: "Review checklist.",
    )

  let #(next, fx, policy) =
    apply_pool_update(
      model,
      pool_messages.MemberTaskDetailEditSubmitted,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert Some("Title required") = next.member_task_detail_edit_error
  let assert False = next.member_task_detail_edit_in_flight
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_detail_edit_submitted_unchanged_stops_editing_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_detail_editing: True,
      member_task_detail_edit_title: "Prepare release",
      member_task_detail_edit_description: "Review checklist.",
      member_task_detail_edit_priority: "2",
      member_task_detail_edit_type_id: "1",
      member_task_detail_edit_error: Some("old"),
    )

  let #(next, fx, policy) =
    apply_pool_update(
      model,
      pool_messages.MemberTaskDetailEditSubmitted,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert False = next.member_task_detail_editing
  let assert "Prepare release" = next.member_task_detail_edit_title
  let assert "Review checklist." = next.member_task_detail_edit_description
  let assert None = next.member_task_detail_edit_error
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_detail_edit_submitted_changed_sets_in_flight_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_detail_editing: True,
      member_task_detail_edit_title: " Updated title ",
      member_task_detail_edit_description: "Updated description",
      member_task_detail_edit_priority: "2",
      member_task_detail_edit_type_id: "1",
    )

  let #(next, fx, policy) =
    apply_pool_update(
      model,
      pool_messages.MemberTaskDetailEditSubmitted,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert "Updated title" = next.member_task_detail_edit_title
  let assert "Updated description" = next.member_task_detail_edit_description
  let assert True = next.member_task_detail_edit_in_flight
  let assert None = next.member_task_detail_edit_error
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx != effect.none()
}

pub fn local_task_updated_ok_replaces_task_and_stops_editing_test() {
  let updated =
    Task(
      ..sample_task(),
      title: "Updated title",
      description: Some("Updated description"),
      version: 4,
    )
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_tasks: remote.Loaded([sample_task()]),
      member_task_detail_editing: True,
      member_task_detail_edit_in_flight: True,
      member_task_detail_edit_error: Some("old"),
    )

  let #(next, fx, policy) =
    apply_pool_update(
      model,
      pool_messages.MemberTaskUpdated(Ok(updated)),
      dispatch_context(),
    )

  let assert True = next.member_tasks == remote.Loaded([updated])
  let assert False = next.member_task_detail_editing
  let assert "Updated title" = next.member_task_detail_edit_title
  let assert "Updated description" = next.member_task_detail_edit_description
  let assert False = next.member_task_detail_edit_in_flight
  let assert None = next.member_task_detail_edit_error
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx != effect.none()
}

pub fn local_task_updated_error_sets_edit_error_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_task_detail_edit_in_flight: True,
      member_task_detail_edit_error: None,
    )

  let err = sample_error()
  let #(next, fx, policy) =
    apply_pool_update(
      model,
      pool_messages.MemberTaskUpdated(Error(err)),
      dispatch_context(),
    )

  let assert False = next.member_task_detail_edit_in_flight
  let assert Some("boom") = next.member_task_detail_edit_error
  let assert detail_update.CheckAuthAfter(auth_err) = policy
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}

pub fn local_task_metrics_fetched_ok_sets_loaded_metrics_test() {
  let metrics = sample_metrics()
  let #(next, fx, policy) =
    apply_pool_update(
      member_pool.default_model(),
      pool_messages.MemberTaskMetricsFetched(Ok(metrics)),
      dispatch_context(),
    )

  let assert True = next.member_task_detail_metrics == remote.Loaded(metrics)
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_metrics_fetched_error_sets_failed_metrics_test() {
  let err = sample_error()
  let #(next, fx, policy) =
    apply_pool_update(
      member_pool.default_model(),
      pool_messages.MemberTaskMetricsFetched(Error(err)),
      dispatch_context(),
    )

  let assert True = next.member_task_detail_metrics == remote.Failed(err)
  let assert detail_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}
