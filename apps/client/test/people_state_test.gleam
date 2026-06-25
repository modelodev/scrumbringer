import gleam/int
import gleam/list
import gleam/option.{None, Some}

import domain/task.{type Task, Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/people/state as people_state

fn make_task(id: Int, user_id: Int, mode: task_state.TaskClaimMode) -> Task {
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
    ongoing_by: None,
    title: "Task #" <> int.to_string(id),
    description: None,
    priority: 3,
    state: state,
    created_by: 1,
    created_at: "2026-02-01T09:00:00Z",
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

fn available_task(id: Int) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Task #" <> int.to_string(id),
    description: None,
    priority: 3,
    state: task_state.Available,
    created_by: 1,
    created_at: "2026-02-01T09:00:00Z",
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

fn blocked(task: Task) -> Task {
  Task(..task, blocked_count: 1)
}

fn active_task_ids(person: people_state.PersonStatus) -> List(Int) {
  let people_state.PersonStatus(active_tasks: active, ..) = person
  active |> list.map(fn(task) { task.id })
}

fn claimed_task_ids(person: people_state.PersonStatus) -> List(Int) {
  let people_state.PersonStatus(claimed_tasks: claimed, ..) = person
  claimed |> list.map(fn(task) { task.id })
}

pub fn derive_status_excludes_ongoing_task_from_claimed_test() {
  let tasks = [make_task(1, 10, task_state.Ongoing)]

  let person = people_state.derive_status(10, "ana@example.com", tasks)
  let assert [1] = active_task_ids(person)
  let assert [] = claimed_task_ids(person)
}

pub fn derive_status_keeps_non_active_taken_tasks_in_claimed_test() {
  let tasks = [
    make_task(1, 10, task_state.Ongoing),
    make_task(2, 10, task_state.Taken),
  ]

  let person = people_state.derive_status(10, "ana@example.com", tasks)
  let assert [2] = claimed_task_ids(person)
}

pub fn roster_claimed_taken_blocked_goes_to_attention_test() {
  let person =
    people_state.derive_status(10, "ana@example.com", [
      make_task(1, 10, task_state.Taken) |> blocked,
    ])

  let assert [row] = people_state.build_roster([person])
  let assert people_state.NeedsAttention = row.section
  let assert Some(people_state.ClaimedWorkBlocked) = row.attention_reason
  let assert Some(task) = row.primary_task
  let assert 1 = task.id
}

pub fn roster_claimed_ongoing_blocked_goes_to_attention_test() {
  let person =
    people_state.derive_status(10, "ana@example.com", [
      make_task(1, 10, task_state.Ongoing) |> blocked,
    ])

  let assert [row] = people_state.build_roster([person])
  let assert people_state.NeedsAttention = row.section
  let assert Some(people_state.OngoingWorkBlocked) = row.attention_reason
}

pub fn roster_available_blocked_is_not_person_work_test() {
  let person =
    people_state.derive_status(10, "ana@example.com", [
      available_task(1) |> blocked,
    ])

  let assert [row] = people_state.build_roster([person])
  let assert people_state.RosterAvailable = row.section
  let assert None = row.primary_task
  let assert None = row.attention_reason
}

pub fn roster_high_load_stays_claimed_work_with_secondary_signal_test() {
  let person =
    people_state.derive_status(10, "ana@example.com", [
      make_task(1, 10, task_state.Taken),
      make_task(2, 10, task_state.Taken),
      make_task(3, 10, task_state.Taken),
      make_task(4, 10, task_state.Taken),
    ])

  let assert [row] = people_state.build_roster([person])
  let assert people_state.RosterClaimedWork = row.section
  let assert Some(people_state.HighClaimedLoadSignal(4)) = row.secondary_signal
  let assert False = people_state.has_attention(person)
}

pub fn roster_unblocked_ongoing_goes_to_working_now_test() {
  let person =
    people_state.derive_status(10, "ana@example.com", [
      make_task(1, 10, task_state.Ongoing),
    ])

  let assert [row] = people_state.build_roster([person])
  let assert people_state.RosterWorkingNow = row.section
}
