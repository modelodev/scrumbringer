import gleam/int
import gleam/option.{None}
import gleam/string
import lustre/element

import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/now_working/mobile
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-03-20T15:00:00Z",
      mode: task_status.Taken,
    )

  Task(
    id: 42,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: "Prepare release",
    description: None,
    priority: 2,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-03-20T14:00:00Z",
    due_date: None,
    version: 3,
    milestone_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn config() -> mobile.Config(String) {
  mobile.Config(
    locale: locale.En,
    theme: theme.Default,
    panel_expanded: True,
    user_id: 7,
    tasks: remote.Loaded([claimed_task()]),
    active_sessions: [],
    server_offset_ms: 0,
    disable_actions: False,
    on_panel_toggled: "panel-toggled",
    on_pause: "pause",
    on_complete: fn(task_id, version) {
      "complete:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_start: fn(task_id) { "start:" <> int.to_string(task_id) },
    on_release: fn(task_id, version) {
      "release:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
  )
}

pub fn mobile_panel_sheet_renders_from_config_test() {
  let html =
    mobile.view_panel_sheet(config())
    |> element.to_document_string

  assert_contains(html, "Working now")
  assert_contains(
    html,
    "Nothing active. Start a task from My Tasks when you are ready to work.",
  )
  assert_contains(html, "My tasks")
  assert_contains(html, "Prepare release")
  assert_contains(html, "Start working")
  assert_contains(html, "Release back to Pool")
}

pub fn mobile_mini_bar_renders_session_count_from_config_test() {
  let html =
    mobile.view_mini_bar(config())
    |> element.to_document_string

  assert_contains(html, "Working now (0)")
}
