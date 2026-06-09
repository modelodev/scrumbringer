import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{ApiError}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/update as tasks_update

fn local_context(selected_project_id) -> tasks_update.CreateContext(Nil) {
  tasks_update.CreateContext(
    selected_project_id: selected_project_id,
    on_task_types_fetched: fn(_project_id, _result) { Nil },
    on_task_created: fn(_result) { Nil },
    select_project_first: "Select a project first",
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1 to 5",
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
    title: "Ship task",
    description: Some("Useful detail"),
    priority: 3,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 7,
    created_at: "2026-03-20T14:00:00Z",
    version: 1,
    milestone_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

pub fn try_task_create_update_opened_returns_local_update_test() {
  let assert Some(tasks_update.TaskCreateUpdate(next, fx, policy)) =
    tasks_update.try_task_create_update(
      member_pool.default_model(),
      pool_messages.MemberCreateDialogOpened,
      local_context(None),
    )

  let assert dialog_mode.DialogCreate = next.member_create_dialog_mode
  let assert tasks_update.NoTaskCreatePolicy = policy
  let assert True = fx == effect.none()
}

pub fn try_task_create_update_success_requests_refresh_with_task_test() {
  let task = sample_task()
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_dialog_mode: dialog_mode.DialogCreate,
      member_create_in_flight: True,
      member_create_title: "Ship task",
    )

  let assert Some(tasks_update.TaskCreateUpdate(next, fx, policy)) =
    tasks_update.try_task_create_update(
      model,
      pool_messages.MemberTaskCreated(Ok(task)),
      local_context(None),
    )
  let assert tasks_update.RefreshMemberAfterTaskCreated(created_task) = policy

  let assert True = created_task == task
  let assert dialog_mode.DialogClosed = next.member_create_dialog_mode
  let assert False = next.member_create_in_flight
  let assert "" = next.member_create_title
  let assert True = fx == effect.none()
}

pub fn try_task_create_update_error_checks_auth_before_local_fallback_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_in_flight: True,
      member_create_error: None,
    )

  let assert Some(tasks_update.TaskCreateUpdate(next, fx, policy)) =
    tasks_update.try_task_create_update(
      model,
      pool_messages.MemberTaskCreated(Error(err)),
      local_context(None),
    )
  let assert tasks_update.CheckTaskCreateAuthBefore(auth_err) = policy

  let assert True = auth_err == err
  let assert False = next.member_create_in_flight
  let assert Some("boom") = next.member_create_error
  let assert True = fx == effect.none()
}

pub fn try_task_create_update_ignores_non_create_messages_test() {
  let assert None =
    tasks_update.try_task_create_update(
      member_pool.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      local_context(None),
    )
}

pub fn local_create_dialog_opened_with_card_sets_card_context_test() {
  let #(next, fx) =
    tasks_update.handle_create_dialog_opened_with_card(
      member_pool.default_model(),
      42,
      local_context(None),
    )

  let assert dialog_mode.DialogCreate = next.member_create_dialog_mode
  let assert Some(42) = next.member_create_card_id
  let assert None = next.member_create_milestone_id
  let assert None = next.member_create_error
  let assert True = fx == effect.none()
}

pub fn local_create_dialog_closed_clears_create_context_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_dialog_mode: dialog_mode.DialogCreate,
      member_create_error: Some("boom"),
      member_create_card_id: Some(7),
      member_create_milestone_id: Some(9),
    )

  let #(next, fx) = tasks_update.handle_create_dialog_closed(model)

  let assert dialog_mode.DialogClosed = next.member_create_dialog_mode
  let assert None = next.member_create_error
  let assert None = next.member_create_card_id
  let assert None = next.member_create_milestone_id
  let assert True = fx == effect.none()
}

pub fn local_create_submitted_without_project_sets_context_error_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_title: "Ship task",
      member_create_type_id: "1",
      member_create_priority: "3",
    )

  let #(next, fx) =
    tasks_update.handle_create_submitted(model, local_context(None))

  let assert Some("Select a project first") = next.member_create_error
  let assert False = next.member_create_in_flight
  let assert True = fx == effect.none()
}

pub fn local_task_created_ok_resets_create_dialog_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_dialog_mode: dialog_mode.DialogCreate,
      member_create_in_flight: True,
      member_create_title: "Ship task",
      member_create_description: "Useful detail",
      member_create_priority: "5",
      member_create_type_id: "8",
      member_create_card_id: Some(7),
      member_create_milestone_id: Some(9),
    )

  let #(next, fx) = tasks_update.handle_task_created_ok(model)

  let assert dialog_mode.DialogClosed = next.member_create_dialog_mode
  let assert False = next.member_create_in_flight
  let assert "" = next.member_create_title
  let assert "" = next.member_create_description
  let assert "3" = next.member_create_priority
  let assert "" = next.member_create_type_id
  let assert None = next.member_create_card_id
  let assert None = next.member_create_milestone_id
  let assert True = fx == effect.none()
}

pub fn local_task_created_error_sets_error_message_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_in_flight: True,
      member_create_error: None,
    )

  let #(next, fx) = tasks_update.handle_task_created_error(model, "boom")

  let assert False = next.member_create_in_flight
  let assert Some("boom") = next.member_create_error
  let assert True = fx == effect.none()
}
