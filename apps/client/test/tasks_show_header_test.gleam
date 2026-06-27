import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/remote.{Loaded}
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/tasks/show/header as task_show_header
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

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

  assert_contains(html, "Prepare release")
  assert_contains(html, "Release card")
  assert_contains(html, "Ready to claim")
  assert_contains(html, "task-show-title")
  assert_not_contains(html, "Available")
  assert_not_contains(html, "Feature")
  assert_not_contains(html, "Backend")
  assert_not_contains(html, "task-meta-capability")
  assert_not_contains(html, "P2")
  assert_not_contains(html, "data-testid=\"task-show-status-indicator\"")
  assert_not_contains(html, "task-status-indicator")
  assert_not_contains(html, "Claim to My Tasks")
  assert_not_contains(html, "No due date")
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

  assert_contains(html, "In My Tasks, ready to start")
  assert_not_contains(html, "Claimed")
  assert_not_contains(html, "data-testid=\"task-show-status-indicator\"")
  assert_not_contains(html, "Claimed by #7")
  assert_not_contains(html, "task-meta-assignee")
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

  assert_contains(html, "Loading")
  assert_contains(html, "task-show-title")
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

  assert_contains(html, "aria-label=\"Cerrar\"")
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

  assert_contains(html, "Due 2026-06-24")
  assert_contains(html, "Blocked by 1 tasks")
  assert_not_contains(html, "Ready to claim")
  assert_not_contains(html, "task-meta-blocking blocking")
}

fn available_task() -> Task {
  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    ongoing_by: None,
    title: "Prepare release",
    description: Some("Task description"),
    priority: 2,
    state: task_state.Available,
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    due_date: None,
    version: 3,
    parent_card_id: None,
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
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
  TaskDependency(
    depends_on_task_id: id,
    title: "Dependency",
    state: state,
    claimed_by: None,
  )
}

fn closed_done_state() -> task_state.TaskExecutionState {
  task_state.Closed(task_state.ClosedByClaimant, "2026-06-01T10:00:00Z", 7)
}
