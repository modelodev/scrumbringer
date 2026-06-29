import gleam/int
import support/domain_fixtures
import support/render_assertions

import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import scrumbringer_client/features/now_working/mobile
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

fn claimed_task() -> Task {
  let state =
    task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-03-20T15:00:00Z",
      mode: task_state.Taken,
    )

  Task(
    ..domain_fixtures.task(42, "Prepare release", 1),
    state: state,
    version: 3,
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
    on_close: fn(task_id) { "close:" <> int.to_string(task_id) },
    on_start: fn(task_id) { "start:" <> int.to_string(task_id) },
    on_release: fn(task_id, version) {
      "release:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
  )
}

pub fn mobile_panel_sheet_renders_from_config_test() {
  let html =
    mobile.view_panel_sheet(config())
    |> render_assertions.html

  render_assertions.contains(html, "Working now")
  render_assertions.contains(
    html,
    "Nothing active. Start a task from My Tasks when you are ready to work.",
  )
  render_assertions.contains(html, "My tasks")
  render_assertions.contains(html, "Prepare release")
  render_assertions.contains(html, "Start working")
  render_assertions.contains(html, "Release back to Pool")
}

pub fn mobile_mini_bar_renders_session_count_from_config_test() {
  let html =
    mobile.view_mini_bar(config())
    |> render_assertions.html

  render_assertions.contains(html, "Working now (0)")
}
