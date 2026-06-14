import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status.{Available, Claimed, Taken}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/task_detail_header
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn task_detail_header_renders_loaded_task_test() {
  let html =
    task_detail_header.view(task_detail_header.Config(
      locale: locale.En,
      task: Some(available_task()),
      on_close: "close",
    ))
    |> element.to_document_string

  assert_contains(html, "Prepare release")
  assert_contains(html, "Feature")
  assert_contains(html, "P2")
  assert_contains(html, "Available")
  assert_contains(html, "Unassigned")
  assert_contains(html, "task-detail-title")
}

pub fn task_detail_header_renders_assigned_task_test() {
  let html =
    task_detail_header.view(task_detail_header.Config(
      locale: locale.En,
      task: Some(claimed_task()),
      on_close: "close",
    ))
    |> element.to_document_string

  assert_contains(html, "Claimed")
  assert_contains(html, "Assigned")
  assert_contains(html, "task-meta-assignee")
}

pub fn task_detail_header_renders_loading_title_test() {
  let html =
    task_detail_header.view(task_detail_header.Config(
      locale: locale.En,
      task: None,
      on_close: "close",
    ))
    |> element.to_document_string

  assert_contains(html, "Loading")
  assert_contains(html, "task-detail-title")
}

pub fn task_detail_header_localizes_close_label_test() {
  let html =
    task_detail_header.view(task_detail_header.Config(
      locale: locale.Es,
      task: Some(available_task()),
      on_close: "close",
    ))
    |> element.to_document_string

  assert_contains(html, "aria-label=\"Cerrar\"")
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
    status: Available,
    work_state: task_state.to_work_state(task_state.Available),
    created_by: 7,
    created_at: "2026-06-01T10:00:00Z",
    version: 3,
    milestone_id: None,
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-06-01T11:00:00Z",
      mode: Taken,
    )

  Task(
    ..available_task(),
    state: state,
    status: Claimed(Taken),
    work_state: task_state.to_work_state(state),
  )
}
