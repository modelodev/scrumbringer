import gleam/int
import gleam/option.{None, Some}
import support/domain_fixtures
import support/render_assertions

import domain/card
import domain/metrics.{MyMetrics, WindowDays}
import domain/remote
import domain/task.{type Task, Task}
import domain/task/state as task_state
import scrumbringer_client/features/my_bar/view as my_bar_view
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
    priority: 2,
    state: state,
    version: 3,
    card_id: Some(9),
  )
}

fn claimed_task_with_card() -> Task {
  Task(
    ..claimed_task(),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
  )
}

fn config() -> my_bar_view.TaskRowConfig(String) {
  my_bar_view.TaskRowConfig(
    locale: locale.En,
    theme: theme.Default,
    user_id: 7,
    active_task_id: None,
    disable_actions: False,
    task_card_info: fn(_task) { #(Some("Release card"), Some(card.Blue)) },
    on_claim: fn(task_id, version) {
      "claim:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_start: fn(task_id) { "start:" <> int.to_string(task_id) },
    on_pause: "pause",
    on_release: fn(task_id, version) {
      "release:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_close: fn(task_id, version) {
      "close:" <> int.to_string(task_id) <> ":" <> int.to_string(version)
    },
    on_task_open: fn(task_id) { "open:" <> int.to_string(task_id) },
  )
}

fn bar_config(tasks: List(Task)) -> my_bar_view.Config(String) {
  my_bar_view.Config(
    locale: locale.En,
    has_active_projects: True,
    member_tasks: remote.Loaded(tasks),
    member_metrics: remote.Loaded(MyMetrics(
      window_days: WindowDays(14),
      claimed_count: 5,
      released_count: 2,
      closed_count: 3,
    )),
    task_row_config: config(),
    on_create_task_in_card: fn(card_id) {
      "create-in-card:" <> int.to_string(card_id)
    },
  )
}

pub fn member_bar_task_row_renders_from_config_test() {
  let html =
    my_bar_view.view_member_bar_task_row(config(), claimed_task())
    |> render_assertions.html

  render_assertions.contains(html, "Prepare release")
  render_assertions.contains(html, "Release card")
  render_assertions.contains(html, "P2")
  render_assertions.contains(html, "Bug")
  render_assertions.contains(html, "Start")
  render_assertions.contains(html, "Release")
  render_assertions.contains(html, "Close task")
}

pub fn my_bar_section_renders_from_config_test() {
  let html =
    my_bar_view.view_bar(bar_config([claimed_task_with_card()]))
    |> render_assertions.html

  render_assertions.contains(html, "My Metrics")
  render_assertions.contains(html, "Window: 14 days")
  render_assertions.contains(html, "Claimed")
  render_assertions.contains(html, "Released")
  render_assertions.contains(html, "Closed")
  render_assertions.contains(html, "Release card")
  render_assertions.contains(html, "Prepare release")
  render_assertions.contains(html, "Add task to Release card")
  render_assertions.contains(html, "my-bar-add-task")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.not_contains(
    html,
    "class=\"btn-icon btn-sm my-bar-add-task\"",
  )
}
