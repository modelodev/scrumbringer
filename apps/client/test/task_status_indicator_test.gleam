import gleam/option.{Some}
import support/render_assertions

import domain/task_status
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_status_indicator
import scrumbringer_client/ui/tone

pub fn task_status_indicator_maps_status_semantics_test() {
  let assert icons.InboxEmpty =
    task_status_indicator.icon(task_status.Available)
  let assert icons.ClipboardDoc =
    task_status_indicator.icon(task_status.Claimed(task_status.Taken))
  let assert icons.Play =
    task_status_indicator.icon(task_status.Claimed(task_status.Ongoing))
  let assert icons.CheckCircle = task_status_indicator.icon(task_status.Closed)

  let assert tone.Available = task_status_indicator.tone(task_status.Available)
  let assert tone.Claimed =
    task_status_indicator.tone(task_status.Claimed(task_status.Taken))
  let assert tone.Ongoing =
    task_status_indicator.tone(task_status.Claimed(task_status.Ongoing))
  let assert tone.Success = task_status_indicator.tone(task_status.Closed)
}

pub fn full_status_indicator_renders_label_and_accessibility_test() {
  let html =
    task_status_indicator.full(
      locale.En,
      task_status.Claimed(task_status.Ongoing),
    )
    |> render_assertions.html

  render_assertions.contains(html, "task-status-indicator is-full ongoing")
  render_assertions.contains(html, "data-testid=\"task-status-indicator\"")
  render_assertions.contains(html, "title=\"Active work session is running\"")
  render_assertions.contains(
    html,
    "aria-label=\"Active work session is running\"",
  )
  render_assertions.contains(html, "task-status-indicator-icon")
  render_assertions.contains(html, "nav-icon")
  render_assertions.contains(html, "task-status-indicator-label")
  render_assertions.contains(html, ">Working now<")
}

pub fn compact_status_indicator_hides_label_but_keeps_accessibility_test() {
  let html =
    task_status_indicator.compact(locale.En, task_status.Closed)
    |> render_assertions.html

  render_assertions.contains(html, "task-status-indicator is-compact success")
  render_assertions.contains(html, "title=\"Closed and no longer actionable\"")
  render_assertions.contains(
    html,
    "aria-label=\"Closed and no longer actionable\"",
  )
  render_assertions.contains(html, "task-status-indicator-icon")
  render_assertions.not_contains(html, "task-status-indicator-label")
}

pub fn status_indicator_accepts_contextual_visible_label_test() {
  let html =
    task_status_indicator.view(task_status_indicator.Config(
      locale: locale.En,
      status: task_status.Claimed(task_status.Taken),
      variant: task_status_indicator.InlineFull,
      label: Some("Claimed by ada@example.com"),
      title: Some("Claimed by ada@example.com"),
      extra_class: Some("task-claimed-by"),
      testid: Some("claimed-by"),
    ))
    |> render_assertions.html

  render_assertions.contains(html, "task-claimed-by")
  render_assertions.contains(html, "data-testid=\"claimed-by\"")
  render_assertions.contains(html, "title=\"Claimed by ada@example.com\"")
  render_assertions.contains(html, ">Claimed by ada@example.com<")
}
