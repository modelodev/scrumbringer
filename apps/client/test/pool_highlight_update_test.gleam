import gleam/option.{None, Some}
import gleeunit/should

import domain/remote.{Loaded}
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task_state
import domain/task_type.{TaskTypeInline}

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/update as pool_update

fn make_dependency(depends_on_task_id: Int) -> TaskDependency {
  TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: "Dependency",
    status: task_state.to_status(task_state.Available),
    claimed_by: None,
  )
}

fn make_task(
  id: Int,
  blocked_count: Int,
  dependencies: List(TaskDependency),
) -> Task {
  let state = task_state.Available
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Task",
    description: Some("Task description"),
    priority: 3,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
    version: 1,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: blocked_count,
    dependencies: dependencies,
  )
}

pub fn hover_open_sets_blocking_highlight_with_hidden_count_test() {
  let source = make_task(1, 1, [make_dependency(2)])

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_tasks: Loaded([source])),
      )
    })

  let #(next, _fx) = pool_update.handle_task_hover_opened(model, 1)

  next.member.pool.member_highlight_state
  |> should.equal(member_pool.BlockingHighlight(1, [2], 1))
}

pub fn hover_open_on_unblocked_task_keeps_no_highlight_test() {
  let source = make_task(1, 0, [])

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_tasks: Loaded([source])),
      )
    })

  let #(next, _fx) = pool_update.handle_task_hover_opened(model, 1)

  next.member.pool.member_highlight_state
  |> should.equal(member_pool.NoHighlight)
}

pub fn hover_open_with_visible_blocker_sets_hidden_count_zero_test() {
  let source = make_task(1, 1, [make_dependency(2)])
  let blocker = make_task(2, 0, [])

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_tasks: Loaded([source, blocker])),
      )
    })

  let #(next, _fx) = pool_update.handle_task_hover_opened(model, 1)

  next.member.pool.member_highlight_state
  |> should.equal(member_pool.BlockingHighlight(1, [2], 0))
}

pub fn hover_close_clears_blocking_highlight_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_highlight_state: member_pool.BlockingHighlight(10, [11], 0),
        ),
      )
    })

  let #(next, _fx) = pool_update.handle_task_hover_closed(model)

  next.member.pool.member_highlight_state
  |> should.equal(member_pool.NoHighlight)
}

pub fn focus_sets_blocking_highlight_with_hidden_count_test() {
  let source = make_task(1, 1, [make_dependency(2)])

  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_tasks: Loaded([source])),
      )
    })

  let #(next, _fx) = pool_update.handle_task_focused(model, 1)

  next.member.pool.member_highlight_state
  |> should.equal(member_pool.BlockingHighlight(1, [2], 1))
}

pub fn blur_clears_blocking_highlight_test() {
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_highlight_state: member_pool.BlockingHighlight(10, [11], 0),
        ),
      )
    })

  let #(next, _fx) = pool_update.handle_task_blurred(model)

  next.member.pool.member_highlight_state
  |> should.equal(member_pool.NoHighlight)
}
