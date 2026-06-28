import gleam/option.{type Option, Some}
import support/domain_fixtures

import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/show/headline
import scrumbringer_client/i18n/locale

pub fn headline_available_task_prioritizes_next_action_test() {
  let assert "Ready to claim · Release card" =
    headline.text(config(available_task(), Some(7), Loaded([])))
}

pub fn headline_blocked_task_prioritizes_blocker_count_test() {
  let assert "Blocked by 1 tasks · Release card · Due 2026-06-24" =
    headline.text(config(
      Task(..available_task(), due_date: Some("2026-06-24")),
      Some(7),
      Loaded([dependency(11, task_state.Available)]),
    ))
}

pub fn headline_claimed_by_current_user_explains_next_step_test() {
  let assert "In My Tasks, ready to start · Release card" =
    headline.text(config(claimed_task(7, task_state.Taken), Some(7), Loaded([])))
}

pub fn headline_claimed_by_other_user_explains_unavailable_work_test() {
  let assert "Claimed by another user · Release card" =
    headline.text(config(claimed_task(9, task_state.Taken), Some(7), Loaded([])))
}

pub fn headline_ongoing_by_current_user_explains_active_focus_test() {
  let assert "You are working now · Release card" =
    headline.text(config(
      claimed_task(7, task_state.Ongoing),
      Some(7),
      Loaded([]),
    ))
}

pub fn headline_closed_task_is_terminal_test() {
  let assert "Closed · Release card" =
    headline.text(config(closed_task(), Some(7), Loaded([])))
}

fn config(
  task: Task,
  current_user_id: Option(Int),
  dependencies: Remote(List(TaskDependency)),
) -> headline.Config {
  headline.Config(
    locale: locale.En,
    task: task,
    parent_card_title: Some("Release card"),
    current_user_id: current_user_id,
    dependencies: dependencies,
  )
}

fn available_task() -> Task {
  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    priority: 2,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    version: 3,
    card_id: Some(10),
    card_title: Some("Release card"),
  )
}

fn claimed_task(claimed_by: Int, mode: task_state.TaskClaimMode) -> Task {
  Task(
    ..available_task(),
    state: task_state.Claimed(
      claimed_by: claimed_by,
      claimed_at: "2026-06-01T11:00:00Z",
      mode: mode,
    ),
  )
}

fn closed_task() -> Task {
  Task(
    ..available_task(),
    state: task_state.Closed(
      task_state.ClosedByClaimant,
      "2026-06-01T12:00:00Z",
      7,
    ),
  )
}

fn dependency(id: Int, state: task_state.TaskExecutionState) -> TaskDependency {
  TaskDependency(..domain_fixtures.dependency(id), state: state)
}
