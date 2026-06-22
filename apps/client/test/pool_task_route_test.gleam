import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/task_route

fn no_refresh(model: client_state.Model) {
  #(model, effect.none())
}

fn refresh_to_loading(model: client_state.Model) {
  let next =
    client_state.update_member(model, fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: remote.Loading,
          member_tasks_pending: 1,
        ),
      )
    })

  #(next, effect.none())
}

fn model_with_pool(pool: member_pool.Model) -> client_state.Model {
  client_state.update_member(client_state.default_model(), fn(member) {
    member_state.MemberModel(..member, pool: pool)
  })
}

fn model_with_open_task_show(task_id: Int) -> client_state.Model {
  client_state.update_member(client_state.default_model(), fn(member) {
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..member.pool,
        member_task_show_edit_title: "Open task",
        member_task_show_edit_description: "Details",
        member_task_show_edit_priority: "2",
        member_task_show_edit_type_id: "5",
      ),
      notes: member_notes.Model(
        ..member.notes,
        member_notes_task_id: opt.Some(task_id),
        member_notes: remote.Loading,
      ),
    )
  })
}

pub fn try_update_routes_task_create_opened_test() {
  let assert opt.Some(#(next, fx)) =
    task_route.try_update(
      client_state.default_model(),
      pool_messages.MemberCreateDialogOpened,
      no_refresh,
    )

  let assert dialog_mode.DialogCreate =
    next.member.pool.member_create_dialog_mode
  let assert True = fx == effect.none()
}

pub fn try_update_handles_create_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")
  let model =
    model_with_pool(
      member_pool.Model(
        ..member_pool.default_model(),
        member_create_in_flight: True,
      ),
    )

  let assert opt.Some(#(next, fx)) =
    task_route.try_update(
      model,
      pool_messages.MemberTaskCreated(Error(err)),
      no_refresh,
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = next.member.pool.member_create_in_flight
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_task_messages_test() {
  let assert opt.None =
    task_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      no_refresh,
    )
}

pub fn task_delete_success_closes_deleted_task_show_test() {
  let assert opt.Some(#(next, _fx)) =
    task_route.try_update(
      model_with_open_task_show(42),
      pool_messages.MemberTaskDeleted(42, Ok(Nil)),
      no_refresh,
    )

  let assert opt.None = next.member.notes.member_notes_task_id
  let assert "" = next.member.pool.member_task_show_edit_title
  let assert "3" = next.member.pool.member_task_show_edit_priority
}

pub fn task_delete_success_keeps_other_task_show_open_test() {
  let assert opt.Some(#(next, _fx)) =
    task_route.try_update(
      model_with_open_task_show(99),
      pool_messages.MemberTaskDeleted(42, Ok(Nil)),
      no_refresh,
    )

  let assert opt.Some(99) = next.member.notes.member_notes_task_id
  let assert "Open task" = next.member.pool.member_task_show_edit_title
  let assert "2" = next.member.pool.member_task_show_edit_priority
}

pub fn task_release_success_refresh_preserves_loaded_tasks_test() {
  let task = sample_task(42)
  let model =
    model_with_pool(
      member_pool.Model(
        ..member_pool.default_model(),
        member_tasks: remote.Loaded([task]),
        member_task_mutation_in_flight: True,
        member_task_mutation_task_id: opt.Some(42),
        member_tasks_snapshot: opt.Some([]),
      ),
    )

  let assert opt.Some(#(next, _fx)) =
    task_route.try_update(
      model,
      pool_messages.MemberTaskReleased(Ok(task)),
      refresh_to_loading,
    )

  let assert True = next.member.pool.member_tasks == remote.Loaded([task])
  let assert 1 = next.member.pool.member_tasks_pending
}

fn sample_task(id: Int) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: opt.None,
    title: "Task",
    description: opt.None,
    priority: 1,
    state: task_state.Available,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    due_date: opt.None,
    version: 1,
    parent_card_id: opt.None,
    card_id: opt.None,
    card_title: opt.None,
    card_color: opt.None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: opt.None,
  )
}
