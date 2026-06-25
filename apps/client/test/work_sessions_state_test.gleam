import gleam/option as opt

import domain/remote.{Loaded}
import domain/task.{type Task, type WorkSession, OngoingBy, Task, WorkSession}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/work_sessions_state

fn task(id: Int, user_id: Int, mode: task_state.TaskClaimMode) -> Task {
  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug"),
    ongoing_by: opt.None,
    title: "Task",
    description: opt.None,
    priority: 1,
    state: task_state.Claimed(
      claimed_by: user_id,
      claimed_at: "2026-01-01T00:00:00Z",
      mode: mode,
    ),
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

fn session(task_id: Int) -> WorkSession {
  WorkSession(
    task_id: task_id,
    started_at: "2026-01-01T10:00:00Z",
    accumulated_s: 0,
  )
}

pub fn apply_active_sessions_marks_current_user_task_ongoing_test() {
  let assert Loaded([updated]) =
    work_sessions_state.apply_active_sessions(
      Loaded([task(89, 1, task_state.Taken)]),
      opt.Some(1),
      [session(89)],
    )

  let assert task_state.Claimed(mode: task_state.Ongoing, ..) = updated.state
  let assert opt.Some(OngoingBy(1)) = updated.ongoing_by
}

pub fn apply_active_sessions_downgrades_only_current_user_without_session_test() {
  let assert Loaded([mine, other]) =
    work_sessions_state.apply_active_sessions(
      Loaded([
        task(89, 1, task_state.Ongoing),
        task(90, 2, task_state.Ongoing),
      ]),
      opt.Some(1),
      [],
    )

  let assert task_state.Claimed(mode: task_state.Taken, ..) = mine.state
  let assert task_state.Claimed(mode: task_state.Ongoing, ..) = other.state
}

pub fn mark_task_ongoing_uses_task_id_when_start_payload_is_empty_test() {
  let assert Loaded([updated]) =
    work_sessions_state.mark_task_ongoing(
      Loaded([task(89, 1, task_state.Taken)]),
      89,
      opt.Some(1),
    )

  let assert task_state.Claimed(mode: task_state.Ongoing, ..) = updated.state
  let assert opt.Some(OngoingBy(1)) = updated.ongoing_by
}

pub fn mark_task_taken_uses_task_id_when_pause_payload_is_empty_test() {
  let assert Loaded([updated]) =
    work_sessions_state.mark_task_taken(
      Loaded([task(89, 1, task_state.Ongoing)]),
      89,
      opt.Some(1),
    )

  let assert task_state.Claimed(mode: task_state.Taken, ..) = updated.state
  let assert opt.None = updated.ongoing_by
}
