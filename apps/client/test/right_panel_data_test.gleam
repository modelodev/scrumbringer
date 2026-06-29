import gleam/option.{None, Some}
import support/domain_fixtures

import domain/card.{Active, Blue, Card, Gray}
import domain/remote.{Loaded, NotAsked}
import domain/task.{Task, WorkSession}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/layout/right_panel
import scrumbringer_client/features/layout/right_panel_data

pub fn loaded_tasks_or_empty_returns_loaded_tasks_and_defaults_empty_test() {
  let loaded = Loaded([task(1, task_state.Available)])

  let assert [loaded_task] = right_panel_data.loaded_tasks_or_empty(loaded)
  let assert 1 = loaded_task.id
  let assert [] = right_panel_data.loaded_tasks_or_empty(NotAsked)
}

pub fn claimed_tasks_keeps_only_taken_tasks_for_user_test() {
  let tasks = [
    task(1, task_state.Claimed(7, "2026-06-01T10:00:00Z", task_state.Taken)),
    task(2, task_state.Claimed(8, "2026-06-01T10:00:00Z", task_state.Taken)),
    task(3, task_state.Available),
  ]

  let assert [claimed] = right_panel_data.claimed_tasks(tasks, 7)
  let assert 1 = claimed.id
}

pub fn my_cards_returns_cards_with_user_claimed_tasks_and_progress_test() {
  let cards = [
    card(1, "Release", Some(Blue)),
    card(2, "Backlog", Some(Gray)),
  ]
  let tasks = [
    Task(
      ..task(1, task_state.Claimed(7, "2026-06-01T10:00:00Z", task_state.Taken)),
      card_id: Some(1),
    ),
    Task(
      ..task(
        2,
        task_state.Closed(
          task_state.ClosedByClaimant,
          "2026-06-02T10:00:00Z",
          7,
        ),
      ),
      card_id: Some(1),
    ),
    Task(
      ..task(3, task_state.Claimed(8, "2026-06-01T10:00:00Z", task_state.Taken)),
      card_id: Some(2),
    ),
  ]

  let assert [progress] = right_panel_data.my_cards(cards, tasks, 7)
  let assert right_panel.MyCardProgress(
    card_id: 1,
    card_title: "Release",
    card_color: Some(Blue),
    closed: 1,
    total: 2,
  ) = progress
}

pub fn active_tasks_uses_task_metadata_and_missing_task_fallback_test() {
  let sessions = [
    WorkSession(
      task_id: 1,
      started_at: "2026-06-01T10:00:00Z",
      accumulated_s: 60,
    ),
    WorkSession(
      task_id: 99,
      started_at: "2026-06-01T10:00:00Z",
      accumulated_s: 0,
    ),
  ]
  let tasks = [Task(..task(1, task_state.Available), title: "Fix login")]

  let assert [known, missing] =
    right_panel_data.active_tasks(
      sessions,
      tasks,
      0,
      120_000,
      fn(_) { 0 },
      fn(_) { Some(Blue) },
    )

  let assert "Fix login" = known.task_title
  let assert "sparkles" = known.task_type_icon
  let assert Some(Blue) = known.card_color
  let assert "Task #99" = missing.task_title
  let assert "clipboard-document" = missing.task_type_icon
  let assert None = missing.card_color
}

fn card(id: Int, title: String, color) {
  Card(
    ..domain_fixtures.card(id, 1, title),
    state: Active,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    color: color,
  )
}

fn task(id: Int, state: task_state.TaskExecutionState) {
  Task(
    ..domain_fixtures.task(id, "Task", 1),
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    description: None,
    priority: 2,
    state: state,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
  )
}
