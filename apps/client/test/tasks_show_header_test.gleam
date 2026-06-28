import gleam/option.{None, Some}
import lustre/element
import support/domain_fixtures
import support/render_assertions

import domain/remote.{Loaded}
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task/state as task_state
import scrumbringer_client/features/tasks/show/header as task_show_header
import scrumbringer_client/i18n/locale

pub fn task_show_header_renders_loaded_task_test() {
  let html =
    task_show_header.view(task_show_header.Config(
      locale: locale.En,
      task: Some(available_task()),
      parent_card_title: Some("Release card"),
      current_user_id: Some(7),
      dependencies: Loaded([]),
      actions: None,
      on_close: "close",
    ))
    |> element.to_document_string

  render_assertions.contains(html, "Prepare release")
  render_assertions.contains(html, "Release card")
  render_assertions.contains(html, "Ready to claim")
  render_assertions.contains(html, "task-show-title")
  render_assertions.not_contains(html, "Available")
  render_assertions.not_contains(html, "Feature")
  render_assertions.not_contains(html, "Backend")
  render_assertions.not_contains(html, "task-meta-capability")
  render_assertions.not_contains(html, "P2")
  render_assertions.not_contains(
    html,
    "data-testid=\"task-show-status-indicator\"",
  )
  render_assertions.not_contains(html, "task-status-indicator")
  render_assertions.not_contains(html, "Claim to My Tasks")
  render_assertions.not_contains(html, "No due date")
}

pub fn task_show_header_renders_claimed_state_without_owner_chip_test() {
  let html =
    task_show_header.view(task_show_header.Config(
      locale: locale.En,
      task: Some(claimed_task()),
      parent_card_title: Some("Release card"),
      current_user_id: Some(7),
      dependencies: Loaded([]),
      actions: None,
      on_close: "close",
    ))
    |> element.to_document_string

  render_assertions.contains(html, "In My Tasks, ready to start")
  render_assertions.not_contains(html, "Claimed")
  render_assertions.not_contains(
    html,
    "data-testid=\"task-show-status-indicator\"",
  )
  render_assertions.not_contains(html, "Claimed by #7")
  render_assertions.not_contains(html, "task-meta-assignee")
}

pub fn task_show_header_renders_loading_title_test() {
  let html =
    task_show_header.view(task_show_header.Config(
      locale: locale.En,
      task: None,
      parent_card_title: None,
      current_user_id: None,
      dependencies: Loaded([]),
      actions: None,
      on_close: "close",
    ))
    |> element.to_document_string

  render_assertions.contains(html, "Loading")
  render_assertions.contains(html, "task-show-title")
}

pub fn task_show_header_localizes_close_label_test() {
  let html =
    task_show_header.view(task_show_header.Config(
      locale: locale.Es,
      task: Some(available_task()),
      parent_card_title: Some("Release card"),
      current_user_id: Some(7),
      dependencies: Loaded([]),
      actions: None,
      on_close: "close",
    ))
    |> element.to_document_string

  render_assertions.contains(html, "aria-label=\"Cerrar\"")
}

pub fn task_show_header_renders_due_date_and_loaded_blockers_test() {
  let html =
    task_show_header.view(task_show_header.Config(
      locale: locale.En,
      task: Some(Task(..available_task(), due_date: Some("2026-06-24"))),
      parent_card_title: Some("Release card"),
      current_user_id: Some(7),
      dependencies: Loaded([
        dependency(11, task_state.Available),
        dependency(12, closed_done_state()),
      ]),
      actions: None,
      on_close: "close",
    ))
    |> element.to_document_string

  render_assertions.contains(html, "Due 2026-06-24")
  render_assertions.contains(html, "Blocked by 1 tasks")
  render_assertions.not_contains(html, "Ready to claim")
  render_assertions.not_contains(html, "task-meta-blocking blocking")
}

fn available_task() -> Task {
  domain_fixtures.task(42, "Prepare release", 1)
}

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-06-01T11:00:00Z",
      mode: task_state.Taken,
    )

  Task(..available_task(), state: state)
}

fn dependency(id: Int, state: task_state.TaskExecutionState) -> TaskDependency {
  TaskDependency(..domain_fixtures.dependency(id), state: state)
}

fn closed_done_state() -> task_state.TaskExecutionState {
  task_state.Closed(task_state.ClosedByClaimant, "2026-06-01T10:00:00Z", 7)
}
