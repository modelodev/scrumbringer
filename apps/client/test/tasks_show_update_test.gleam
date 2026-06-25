import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{type ApiError, ApiError}
import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/show/model as task_show_model
import scrumbringer_client/features/tasks/show_update
import scrumbringer_client/ui/show_tabs

fn sample_error() -> ApiError {
  ApiError(status: 500, code: "ERR", message: "boom")
}

fn edit_context(current_task, can_edit) -> show_update.EditContext(Nil) {
  show_update.EditContext(
    current_task: current_task,
    can_edit: can_edit,
    on_task_updated: fn(_result) { Nil },
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1-5",
  )
}

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

fn show_context() -> show_update.Context(Nil) {
  show_update.Context(
    on_task_fetched: fn(_result) { Nil },
    on_notes_fetched: fn(_result) { Nil },
    on_dependencies_fetched: fn(_result) { Nil },
    on_activity_fetched: fn(_result) { Nil },
  )
}

fn dispatch_context() -> show_update.DispatchContext(Nil) {
  dispatch_context_with_edit(Some(sample_task()), True)
}

fn dispatch_context_with_edit(
  current_task,
  can_edit,
) -> show_update.DispatchContext(Nil) {
  show_update.DispatchContext(
    open_context: show_context(),
    edit_context: edit_context(current_task, can_edit),
    success_context: success_context(),
    error_context: error_context(),
  )
}

fn apply_pool_update(model, message, context) {
  let assert Some(show_update.Update(next, fx, policy)) =
    show_update.try_update(show_model(model), message, context)
  #(next, fx, policy)
}

fn apply_show_update(model, message, context) {
  let assert Some(show_update.Update(next, fx, policy)) =
    show_update.try_update(model, message, context)
  #(next, fx, policy)
}

fn show_model(pool: member_pool.Model) -> show_update.Model {
  show_update.Model(
    pool: pool,
    task_show: task_show_model.default(),
    notes: member_notes.default_model(),
    dependencies: member_dependencies.default_model(),
  )
}

fn show_model_with_task_show(
  pool: member_pool.Model,
  task_show: task_show_model.Model,
) -> show_update.Model {
  show_update.Model(
    pool: pool,
    task_show: task_show,
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

pub fn try_update_tab_clicked_sets_tab_without_auth_test() {
  let model = show_model(member_pool.default_model())

  let assert Some(show_update.Update(next, fx, auth_policy)) =
    show_update.try_update(
      model,
      pool_messages.MemberTaskShowTabClicked(show_tabs.TaskActivityTab),
      dispatch_context(),
    )

  let assert show_tabs.TaskActivityTab = next.task_show.active_tab
  let assert True = next.notes == model.notes
  let assert True = next.dependencies == model.dependencies
  let assert show_update.NoAuthCheck = auth_policy
  let assert True = fx == effect.none()
}

pub fn try_update_error_checks_auth_after_local_feedback_test() {
  let err = sample_error()
  let model =
    show_model_with_task_show(
      member_pool.default_model(),
      task_show_model.Model(
        ..task_show_model.default(),
        edit_in_flight: True,
        edit_error: None,
      ),
    )

  let assert Some(show_update.Update(next, fx, auth_policy)) =
    show_update.try_update(
      model,
      pool_messages.MemberTaskUpdated(Error(err)),
      dispatch_context(),
    )
  let assert show_update.CheckAuthAfter(auth_err) = auth_policy

  let assert False = next.task_show.edit_in_flight
  let assert Some("boom") = next.task_show.edit_error
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}

pub fn fetched_task_is_added_to_empty_show_cache_test() {
  let task = sample_task()
  let model = show_model(member_pool.default_model())

  let assert Some(show_update.Update(next, fx, auth_policy)) =
    show_update.try_update(
      model,
      pool_messages.MemberTaskUpdated(Ok(task)),
      dispatch_context(),
    )

  let assert remote.Loaded([cached_task]) = next.pool.member_tasks
  let assert 42 = cached_task.id
  let assert "Prepare release" = next.task_show.edit_title
  let assert show_update.NoAuthCheck = auth_policy
  let assert True = fx != effect.none()
}

pub fn try_update_ignores_non_show_messages_test() {
  let assert None =
    show_update.try_update(
      show_model(member_pool.default_model()),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      dispatch_context(),
    )
}

pub fn local_task_show_tab_clicked_sets_tab_test() {
  let #(next, fx, policy) =
    apply_pool_update(
      member_pool.default_model(),
      pool_messages.MemberTaskShowTabClicked(show_tabs.TaskActivityTab),
      dispatch_context(),
    )

  let assert show_tabs.TaskActivityTab = next.task_show.active_tab
  let assert show_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_show_edit_started_sets_edit_values_when_allowed_test() {
  let #(next, fx, policy) =
    apply_pool_update(
      member_pool.default_model(),
      pool_messages.MemberTaskShowEditStarted,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert True = next.task_show.editing
  let assert "Prepare release" = next.task_show.edit_title
  let assert "Review checklist." = next.task_show.edit_description
  let assert None = next.task_show.edit_error
  let assert show_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_show_edit_started_ignores_disallowed_task_test() {
  let #(next, fx, policy) =
    apply_pool_update(
      member_pool.default_model(),
      pool_messages.MemberTaskShowEditStarted,
      dispatch_context_with_edit(Some(sample_task()), False),
    )

  let assert False = next.task_show.editing
  let assert show_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_show_edit_cancelled_restores_task_values_test() {
  let model =
    show_model_with_task_show(
      member_pool.default_model(),
      task_show_model.Model(
        ..task_show_model.default(),
        editing: True,
        edit_title: "Changed",
        edit_description: "Changed description",
        edit_in_flight: True,
        edit_error: Some("error"),
      ),
    )

  let #(next, fx, policy) =
    apply_show_update(
      model,
      pool_messages.MemberTaskShowEditCancelled,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert False = next.task_show.editing
  let assert "Prepare release" = next.task_show.edit_title
  let assert "Review checklist." = next.task_show.edit_description
  let assert False = next.task_show.edit_in_flight
  let assert None = next.task_show.edit_error
  let assert show_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_show_edit_title_changed_clears_error_test() {
  let model =
    show_model_with_task_show(
      member_pool.default_model(),
      task_show_model.Model(
        ..task_show_model.default(),
        edit_title: "Old",
        edit_error: Some("error"),
      ),
    )

  let #(next, fx, policy) =
    apply_show_update(
      model,
      pool_messages.MemberTaskShowEditTitleChanged("New"),
      dispatch_context(),
    )

  let assert "New" = next.task_show.edit_title
  let assert None = next.task_show.edit_error
  let assert show_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_show_edit_submitted_blank_title_sets_error_test() {
  let model =
    show_model_with_task_show(
      member_pool.default_model(),
      task_show_model.Model(
        ..task_show_model.default(),
        edit_title: "   ",
        edit_description: "Review checklist.",
      ),
    )

  let #(next, fx, policy) =
    apply_show_update(
      model,
      pool_messages.MemberTaskShowEditSubmitted,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert Some("Title required") = next.task_show.edit_error
  let assert False = next.task_show.edit_in_flight
  let assert show_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_show_edit_submitted_unchanged_stops_editing_test() {
  let model =
    show_model_with_task_show(
      member_pool.default_model(),
      task_show_model.Model(
        ..task_show_model.default(),
        editing: True,
        edit_title: "Prepare release",
        edit_description: "Review checklist.",
        edit_priority: "2",
        edit_type_id: "1",
        edit_error: Some("old"),
      ),
    )

  let #(next, fx, policy) =
    apply_show_update(
      model,
      pool_messages.MemberTaskShowEditSubmitted,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert False = next.task_show.editing
  let assert "Prepare release" = next.task_show.edit_title
  let assert "Review checklist." = next.task_show.edit_description
  let assert None = next.task_show.edit_error
  let assert show_update.NoAuthCheck = policy
  let assert True = fx == effect.none()
}

pub fn local_task_show_edit_submitted_changed_sets_in_flight_test() {
  let model =
    show_model_with_task_show(
      member_pool.default_model(),
      task_show_model.Model(
        ..task_show_model.default(),
        editing: True,
        edit_title: " Updated title ",
        edit_description: "Updated description",
        edit_priority: "2",
        edit_type_id: "1",
      ),
    )

  let #(next, fx, policy) =
    apply_show_update(
      model,
      pool_messages.MemberTaskShowEditSubmitted,
      dispatch_context_with_edit(Some(sample_task()), True),
    )

  let assert "Updated title" = next.task_show.edit_title
  let assert "Updated description" = next.task_show.edit_description
  let assert True = next.task_show.edit_in_flight
  let assert None = next.task_show.edit_error
  let assert show_update.NoAuthCheck = policy
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
    show_model_with_task_show(
      member_pool.Model(
        ..member_pool.default_model(),
        member_tasks: remote.Loaded([sample_task()]),
      ),
      task_show_model.Model(
        ..task_show_model.default(),
        editing: True,
        edit_in_flight: True,
        edit_error: Some("old"),
      ),
    )

  let #(next, fx, policy) =
    apply_show_update(
      model,
      pool_messages.MemberTaskUpdated(Ok(updated)),
      dispatch_context(),
    )

  let assert True = next.pool.member_tasks == remote.Loaded([updated])
  let assert False = next.task_show.editing
  let assert "Updated title" = next.task_show.edit_title
  let assert "Updated description" = next.task_show.edit_description
  let assert False = next.task_show.edit_in_flight
  let assert None = next.task_show.edit_error
  let assert show_update.NoAuthCheck = policy
  let assert True = fx != effect.none()
}

pub fn local_task_updated_error_sets_edit_error_test() {
  let model =
    show_model_with_task_show(
      member_pool.default_model(),
      task_show_model.Model(
        ..task_show_model.default(),
        edit_in_flight: True,
        edit_error: None,
      ),
    )

  let err = sample_error()
  let #(next, fx, policy) =
    apply_show_update(
      model,
      pool_messages.MemberTaskUpdated(Error(err)),
      dispatch_context(),
    )

  let assert False = next.task_show.edit_in_flight
  let assert Some("boom") = next.task_show.edit_error
  let assert show_update.CheckAuthAfter(auth_err) = policy
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}
