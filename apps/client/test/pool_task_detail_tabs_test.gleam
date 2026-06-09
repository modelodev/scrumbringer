import gleam/string
import lustre/element
import lustre/element/html

import domain/remote
import domain/task.{type TaskNote, TaskNote}
import scrumbringer_client/features/pool/task_detail_tabs
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/task_tabs

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn task_detail_tabs_render_labels_and_note_count_test() {
  let html =
    task_detail_tabs.view(
      task_detail_tabs.Config(
        locale: locale.En,
        active_tab: task_tabs.TasksTab,
        notes: remote.Loaded([note(1), note(2)]),
        on_tab_clicked: fn(_) { "tab" },
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Tasks")
  assert_contains(html, "Notes")
  assert_contains(html, "Metrics")
  assert_contains(html, "2")
}

pub fn task_detail_tabs_panel_sets_accessible_tab_contract_test() {
  let html =
    task_detail_tabs.panel(task_tabs.MetricsTab, html.div([], []))
    |> element.to_document_string

  assert_contains(html, "detail-tabpanel")
  assert_contains(html, "role=\"tabpanel\"")
  assert_contains(html, "modal-tabpanel-2")
  assert_contains(html, "aria-labelledby=\"modal-tab-2\"")
}

fn note(id: Int) -> TaskNote {
  TaskNote(
    id: id,
    task_id: 42,
    user_id: 7,
    content: "Note",
    created_at: "2026-06-01T10:00:00Z",
  )
}
