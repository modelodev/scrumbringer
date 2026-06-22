import gleam/dict
import gleam/option as opt
import lustre/effect

import domain/api_error.{ApiError}
import domain/remote.{Loaded}
import domain/task.{type Task, type TaskPosition, Task, TaskPosition}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/positions_route

fn model_with_positions(positions: member_positions.Model) -> client_state.Model {
  client_state.update_member(client_state.default_model(), fn(member) {
    member_state.MemberModel(..member, positions: positions)
  })
}

fn model_with_loaded_tasks(tasks: List(Task)) -> client_state.Model {
  client_state.update_member(client_state.default_model(), fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, member_tasks: Loaded(tasks)),
    )
  })
}

pub fn try_update_routes_position_opened_test() {
  let assert opt.Some(#(next, fx)) =
    positions_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPositionEditOpened(7),
    )

  let assert opt.Some(7) = next.member.positions.member_position_edit_task
  let assert True = fx == effect.none()
}

pub fn fetched_positions_compact_loaded_pool_tasks_only_test() {
  let model = model_with_loaded_tasks([task(10), task(11)])
  let positions = [
    position(10, 61, 195),
    position(11, 283, 210),
    position(99, 0, 0),
  ]

  let assert opt.Some(#(next, fx)) =
    positions_route.try_update(
      model,
      pool_messages.MemberPositionsFetched(Ok(positions)),
    )

  let result = next.member.positions.member_positions_by_task
  let assert Ok(#(12, 12)) = dict.get(result, 10)
  let assert Ok(#(234, 27)) = dict.get(result, 11)
  let assert Ok(#(0, 0)) = dict.get(result, 99)
  let assert True = fx == effect.none()
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")
  let model =
    model_with_positions(
      member_positions.Model(
        ..member_positions.default_model(),
        member_position_edit_in_flight: True,
      ),
    )

  let assert opt.Some(#(next, fx)) =
    positions_route.try_update(
      model,
      pool_messages.MemberPositionSaved(Error(err)),
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = next.member.positions.member_position_edit_in_flight
  let assert opt.None = next.member.positions.member_position_edit_error
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_position_messages_test() {
  let assert opt.None =
    positions_route.try_update(
      client_state.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
    )
}

fn task(id: Int) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug"),
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

fn position(task_id: Int, x: Int, y: Int) -> TaskPosition {
  TaskPosition(
    task_id: task_id,
    user_id: 1,
    x: x,
    y: y,
    updated_at: "2026-01-01T00:00:00Z",
  )
}
