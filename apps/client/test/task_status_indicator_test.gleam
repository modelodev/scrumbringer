import gleam/option.{Some}
import gleam/string
import lustre/element

import domain/task_status
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_status_indicator
import scrumbringer_client/ui/tone

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

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
    |> element.to_document_string

  assert_contains(html, "task-status-indicator is-full ongoing")
  assert_contains(html, "data-testid=\"task-status-indicator\"")
  assert_contains(html, "title=\"Active work session is running\"")
  assert_contains(html, "aria-label=\"Active work session is running\"")
  assert_contains(html, "task-status-indicator-icon")
  assert_contains(html, "nav-icon")
  assert_contains(html, "task-status-indicator-label")
  assert_contains(html, ">Working now<")
}

pub fn compact_status_indicator_hides_label_but_keeps_accessibility_test() {
  let html =
    task_status_indicator.compact(locale.En, task_status.Closed)
    |> element.to_document_string

  assert_contains(html, "task-status-indicator is-compact success")
  assert_contains(html, "title=\"Closed and no longer actionable\"")
  assert_contains(html, "aria-label=\"Closed and no longer actionable\"")
  assert_contains(html, "task-status-indicator-icon")
  assert_not_contains(html, "task-status-indicator-label")
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
    |> element.to_document_string

  assert_contains(html, "task-claimed-by")
  assert_contains(html, "data-testid=\"claimed-by\"")
  assert_contains(html, "title=\"Claimed by ada@example.com\"")
  assert_contains(html, ">Claimed by ada@example.com<")
}
