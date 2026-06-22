import gleam/int
import gleam/option.{None, Some}
import gleam/string
import lustre/element

import domain/note/entity.{type Note, Note}
import domain/note/id as note_id
import domain/note/subject.{TaskNoteSubject}
import domain/org_role
import domain/project/id as project_id
import domain/remote
import domain/task/id as task_id
import domain/user/id as user_id
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/features/pool/task_notes
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn task_notes_renders_loaded_notes_test() {
  let html =
    task_notes.view(config(
      current_user_id: Some(7),
      notes: remote.Loaded([
        note(1, user_id: 7, content: "Current user note"),
        note(2, user_id: 9, content: "Other user note"),
      ]),
      dialog_mode: dialog_mode.DialogClosed,
      note_content: "",
      note_in_flight: False,
    ))
    |> element.to_document_string

  assert_contains(html, "task-notes-section")
  assert_contains(html, "Notes")
  assert_contains(html, "You")
  assert_contains(html, "Current user note")
  assert_contains(html, "User #9")
  assert_contains(html, "Other user note")
  assert_not_contains(html, "note-dialog-overlay")
}

pub fn task_notes_renders_empty_state_test() {
  let html =
    task_notes.view(config(
      current_user_id: None,
      notes: remote.Loaded([]),
      dialog_mode: dialog_mode.DialogClosed,
      note_content: "",
      note_in_flight: False,
    ))
    |> element.to_document_string

  assert_contains(html, "No notes yet")
  assert_contains(html, "Add note")
  assert_contains(html, "task-empty-state")
}

pub fn task_notes_renders_create_dialog_test() {
  let html =
    task_notes.view(config(
      current_user_id: Some(7),
      notes: remote.Loaded([]),
      dialog_mode: dialog_mode.DialogCreate,
      note_content: "Draft note",
      note_in_flight: False,
    ))
    |> element.to_document_string

  assert_contains(html, "note-dialog-overlay")
  assert_contains(html, "Draft note")
  assert_contains(html, "Write a note")
  assert_contains(html, "Cancel")
}

fn config(
  current_user_id current_user_id,
  notes notes,
  dialog_mode dialog_mode,
  note_content note_content,
  note_in_flight note_in_flight,
) -> task_notes.Config(String) {
  task_notes.Config(
    locale: locale.En,
    current_user_id: current_user_id,
    can_manage_notes: False,
    notes: notes,
    dialog_mode: dialog_mode,
    note_content: note_content,
    note_error: None,
    note_in_flight: note_in_flight,
    delete_in_flight: None,
    pin_in_flight: None,
    on_dialog_opened: "open",
    on_dialog_closed: "close",
    on_content_changed: fn(value) { "content-" <> value },
    on_submitted: "submit",
    on_delete: fn(_id) { "delete" },
    on_pin_toggle: fn(_id, _pinned) { "pin" },
  )
}

fn note(id: Int, user_id user_id_value: Int, content content: String) -> Note {
  Note(
    id: note_id.new(id),
    project_id: project_id.new(1),
    subject: TaskNoteSubject(task_id.new(10)),
    user_id: user_id.new(user_id_value),
    content: content,
    url: None,
    pinned: False,
    created_at: "2026-06-08T09:00:00Z",
    updated_at: "2026-06-08T09:00:00Z",
    author_email: "user" <> int.to_string(user_id_value) <> "@example.com",
    author_project_role: None,
    author_org_role: org_role.Member,
  )
}
