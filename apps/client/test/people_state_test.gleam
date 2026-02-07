import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleeunit/should

import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/people/state as people_state

fn make_task(
  id: Int,
  user_id: Int,
  mode: task_status.ClaimedState,
  ongoing_by: Option(task_status.OngoingBy),
) -> Task {
  let state =
    task_state.Claimed(
      claimed_by: user_id,
      claimed_at: "2026-02-01T10:00:00Z",
      mode: mode,
    )

  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: ongoing_by,
    title: "Task #" <> int.to_string(id),
    description: None,
    priority: 3,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-02-01T09:00:00Z",
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

fn active_task_ids(person: people_state.PersonStatus) -> List(Int) {
  let people_state.PersonStatus(active_tasks: active, ..) = person
  active |> list.map(fn(task) { task.id })
}

fn claimed_task_ids(person: people_state.PersonStatus) -> List(Int) {
  let people_state.PersonStatus(claimed_tasks: claimed, ..) = person
  claimed |> list.map(fn(task) { task.id })
}

pub fn derive_status_excludes_active_from_claimed_when_ongoing_by_test() {
  let tasks = [
    make_task(
      1,
      10,
      task_status.Taken,
      Some(task_status.OngoingBy(user_id: 10)),
    ),
  ]

  let person = people_state.derive_status(10, "ana@example.com", tasks)
  active_task_ids(person) |> should.equal([1])
  claimed_task_ids(person) |> should.equal([])
}

pub fn derive_status_keeps_non_active_taken_tasks_in_claimed_test() {
  let tasks = [
    make_task(
      1,
      10,
      task_status.Taken,
      Some(task_status.OngoingBy(user_id: 10)),
    ),
    make_task(2, 10, task_status.Taken, None),
  ]

  let person = people_state.derive_status(10, "ana@example.com", tasks)
  claimed_task_ids(person) |> should.equal([2])
}
