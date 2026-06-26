import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{ApiError}
import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/create_update

fn local_context(selected_project_id) -> create_update.Context(Nil) {
  create_update.Context(
    selected_project_id: selected_project_id,
    on_task_types_fetched: fn(_project_id, _result) { Nil },
    on_project_cards_fetched: fn(_project_id, _result) { Nil },
    on_task_created: fn(_result) { Nil },
    select_project_first: "Select a project first",
    title_required: "Title required",
    title_too_long_max_56: "Title too long",
    type_required: "Type required",
    priority_must_be_1_to_5: "Priority must be 1 to 5",
    card_required: "Choose an active card",
    card_has_child_cards: "Choose a task group or empty card",
    parent_card_conflict: "Choose one task location only",
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
    created_by: 7,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 1,
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

pub fn try_task_create_update_opened_returns_local_update_test() {
  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberCreateDialogOpened,
      local_context(None),
    )

  let assert dialog_mode.DialogCreate = next.member_create_dialog_mode
  let assert create_update.NoPolicy = policy
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

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberTaskCreated(Ok(task)),
      local_context(None),
    )
  let assert create_update.RefreshMemberAfterCreated(created_task) = policy

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

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberTaskCreated(Error(err)),
      local_context(None),
    )
  let assert create_update.CheckAuthBefore(auth_err) = policy

  let assert True = auth_err == err
  let assert False = next.member_create_in_flight
  let assert Some("boom") = next.member_create_error
  let assert True = fx == effect.none()
}

pub fn try_task_create_update_ignores_non_create_messages_test() {
  let assert None =
    create_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      local_context(None),
    )
}

pub fn local_create_dialog_opened_with_card_sets_card_context_test() {
  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      member_pool.default_model(),
      pool_messages.MemberCreateDialogOpenedWithCard(42),
      local_context(None),
    )

  let assert create_update.NoPolicy = policy
  let assert dialog_mode.DialogCreate = next.member_create_dialog_mode
  let assert Some(42) = next.member_create_card_id
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
    )

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberCreateDialogClosed,
      local_context(None),
    )

  let assert create_update.NoPolicy = policy
  let assert dialog_mode.DialogClosed = next.member_create_dialog_mode
  let assert None = next.member_create_error
  let assert None = next.member_create_card_id
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

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberCreateSubmitted,
      local_context(None),
    )

  let assert create_update.NoPolicy = policy
  let assert Some("Select a project first") = next.member_create_error
  let assert False = next.member_create_in_flight
  let assert True = fx == effect.none()
}

pub fn local_create_submitted_without_card_sets_card_error_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_title: "Ship task",
      member_create_type_id: "1",
      member_create_priority: "3",
      member_create_card_id: None,
    )

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberCreateSubmitted,
      local_context(Some(1)),
    )

  let assert create_update.NoPolicy = policy
  let assert Some("Choose an active card") = next.member_create_error
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
    )

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberTaskCreated(Ok(sample_task())),
      local_context(None),
    )

  let assert create_update.RefreshMemberAfterCreated(_) = policy
  let assert dialog_mode.DialogClosed = next.member_create_dialog_mode
  let assert False = next.member_create_in_flight
  let assert "" = next.member_create_title
  let assert "" = next.member_create_description
  let assert "3" = next.member_create_priority
  let assert "" = next.member_create_type_id
  let assert None = next.member_create_card_id
  let assert True = fx == effect.none()
}

pub fn local_task_created_error_sets_error_message_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_in_flight: True,
      member_create_error: None,
    )

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberTaskCreated(
        Error(ApiError(status: 500, code: "ERR", message: "boom")),
      ),
      local_context(None),
    )

  let assert create_update.CheckAuthBefore(_) = policy
  let assert False = next.member_create_in_flight
  let assert Some("boom") = next.member_create_error
  let assert True = fx == effect.none()
}

pub fn local_task_created_card_has_child_cards_uses_contextual_message_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_in_flight: True,
      member_create_error: None,
    )

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberTaskCreated(
        Error(ApiError(
          status: 422,
          code: "CARD_HAS_CHILD_CARDS",
          message: "Card already contains child cards",
        )),
      ),
      local_context(None),
    )

  let assert create_update.CheckAuthBefore(_) = policy
  let assert Some("Choose a task group or empty card") =
    next.member_create_error
  let assert True = fx == effect.none()
}

pub fn local_task_created_parent_card_conflict_uses_contextual_message_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_create_in_flight: True,
      member_create_error: None,
    )

  let assert Some(create_update.Update(next, fx, policy)) =
    create_update.try_update(
      model,
      pool_messages.MemberTaskCreated(
        Error(ApiError(
          status: 422,
          code: "TASK_PARENT_CARD_CONFLICT",
          message: "Task cannot specify both card_id and parent_card_id",
        )),
      ),
      local_context(None),
    )

  let assert create_update.CheckAuthBefore(_) = policy
  let assert Some("Choose one task location only") = next.member_create_error
  let assert True = fx == effect.none()
}
