import gleam/option.{None}
import gleam/string
import lustre/element
import lustre/element/html

import domain/note/entity.{type Note, Note}
import domain/note/id as note_id
import domain/note/subject.{TaskNoteSubject}
import domain/org_role
import domain/project/id as project_id
import domain/remote
import domain/task/id as task_id
import domain/user/id as user_id
import scrumbringer_client/features/pool/task_detail_tabs
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/show_tabs

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn task_detail_tabs_render_labels_and_note_count_test() {
  let html =
    task_detail_tabs.view(
      task_detail_tabs.Config(
        locale: locale.En,
        active_tab: show_tabs.TaskDetailsTab,
        notes: remote.Loaded([note(1), note(2)]),
        on_tab_clicked: fn(_) { "tab" },
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Details")
  assert_contains(html, "Dependencies")
  assert_contains(html, "Notes")
  assert_contains(html, "Activity")
  assert_contains(html, "2")
}

pub fn task_detail_tabs_panel_sets_accessible_tab_contract_test() {
  let config =
    task_detail_tabs.Config(
      locale: locale.En,
      active_tab: show_tabs.TaskActivityTab,
      notes: remote.Loaded([]),
      on_tab_clicked: fn(_) { "tab" },
    )

  let html =
    task_detail_tabs.panel(
      show_tabs.TaskActivityTab,
      task_detail_tabs.task_items(config),
      html.div([], []),
    )
    |> element.to_document_string

  assert_contains(html, "detail-tabpanel")
  assert_contains(html, "role=\"tabpanel\"")
  assert_contains(html, "modal-tabpanel-3")
  assert_contains(html, "aria-labelledby=\"modal-tab-3\"")
}

fn note(id: Int) -> Note {
  Note(
    id: note_id.new(id),
    project_id: project_id.new(1),
    subject: TaskNoteSubject(task_id.new(42)),
    user_id: user_id.new(7),
    content: "Note",
    url: None,
    pinned: False,
    created_at: "2026-06-01T10:00:00Z",
    updated_at: "2026-06-01T10:00:00Z",
    author_email: "user@example.com",
    author_project_role: None,
    author_org_role: org_role.Member,
  )
}
