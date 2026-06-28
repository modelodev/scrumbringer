//// Tests for notes list delete context (AC19).

import gleam/int
import gleam/option
import lustre/element
import support/render_assertions

import domain/note/entity.{type Note, Note}
import domain/note/id as note_id
import domain/note/subject.{TaskNoteSubject}
import domain/org_role
import domain/project/id as project_id
import domain/project_role
import domain/task/id as task_id
import domain/user/id as user_id
import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/tooltips/types.{DeleteAsAdmin, DeleteOwnNote}

pub fn from_note_marks_current_user_note_as_own_test() {
  let view = notes_list.from_note(note(1, user_id: 7), own_context())

  let assert "You" = view.author
  let assert True = view.can_pin
  let assert True = view.can_delete
  let assert option.None = view.pin_disabled_reason
  let assert DeleteOwnNote = view.delete_context
}

pub fn from_note_marks_managed_other_user_note_as_admin_context_test() {
  let view =
    notes_list.from_note(
      note(2, user_id: 9),
      notes_list.NoteViewContext(
        ..own_context(),
        can_manage_notes: True,
        current_user_id: option.Some(7),
      ),
    )

  let assert "User #9" = view.author
  let assert True = view.can_pin
  let assert True = view.can_delete
  let assert option.None = view.pin_disabled_reason
  let assert DeleteAsAdmin = view.delete_context
}

pub fn from_note_blocks_other_user_note_without_permission_test() {
  let view = notes_list.from_note(note(2, user_id: 9), own_context())

  let assert "User #9" = view.author
  let assert False = view.can_pin
  let assert False = view.can_delete
  let assert option.Some("Only author or manager") = view.pin_disabled_reason
  let assert DeleteAsAdmin = view.delete_context
}

pub fn from_note_hides_delete_action_while_delete_is_in_flight_test() {
  let view =
    notes_list.from_note(
      note(1, user_id: 7),
      notes_list.NoteViewContext(
        ..own_context(),
        delete_in_flight: option.Some(1),
      ),
    )

  let assert True = view.can_pin
  let assert False = view.can_delete
}

pub fn from_note_marks_pin_action_as_in_flight_test() {
  let view =
    notes_list.from_note(
      note(1, user_id: 7),
      notes_list.NoteViewContext(..own_context(), pin_in_flight: option.Some(1)),
    )

  let assert True = view.pin_in_flight
}

pub fn delete_button_shows_own_note_label_test() {
  let notes = [
    notes_list.NoteView(
      id: 1,
      author: "María García",
      created_at: "14:32",
      content: "Test note",
      url: option.None,
      pinned: False,
      can_pin: True,
      pin_in_flight: False,
      pin_disabled_reason: option.None,
      can_delete: True,
      delete_context: DeleteOwnNote,
      author_email: "maria@example.com",
      author_project_role: option.None,
      author_org_role: org_role.Member,
    ),
  ]

  let html =
    notes_list.view(
      notes,
      "Eliminar nota",
      "Eliminar nota (como admin)",
      "Fijar nota",
      "Desfijar nota",
      fn(id) { id },
      fn(id, _pinned) { id },
    )
    |> element.to_document_string

  render_assertions.contains(html, "Eliminar nota")
  render_assertions.not_contains(html, "(como admin)")
}

fn own_context() -> notes_list.NoteViewContext {
  notes_list.NoteViewContext(
    current_user_id: option.Some(7),
    can_manage_notes: False,
    pin_in_flight: option.None,
    delete_in_flight: option.None,
    you_label: "You",
    user_label: fn(id) { "User #" <> int.to_string(id) },
    cannot_pin_label: "Only author or manager",
  )
}

fn note(id: Int, user_id note_user_id: Int) -> Note {
  Note(
    id: note_id.new(id),
    project_id: project_id.new(1),
    subject: TaskNoteSubject(task_id.new(10)),
    user_id: user_id.new(note_user_id),
    content: "Test note",
    url: option.None,
    pinned: False,
    created_at: "2026-06-08T09:00:00Z",
    updated_at: "2026-06-08T09:00:00Z",
    author_email: "user@example.com",
    author_project_role: option.None,
    author_org_role: org_role.Member,
  )
}

pub fn delete_button_shows_admin_context_test() {
  let notes = [
    notes_list.NoteView(
      id: 1,
      author: "Carlos López",
      created_at: "09:15",
      content: "Another note",
      url: option.None,
      pinned: False,
      can_pin: True,
      pin_in_flight: False,
      pin_disabled_reason: option.None,
      can_delete: True,
      delete_context: DeleteAsAdmin,
      author_email: "carlos@example.com",
      author_project_role: option.Some(project_role.Manager),
      author_org_role: org_role.Admin,
    ),
  ]

  let html =
    notes_list.view(
      notes,
      "Eliminar nota",
      "Eliminar nota (como admin)",
      "Fijar nota",
      "Desfijar nota",
      fn(id) { id },
      fn(id, _pinned) { id },
    )
    |> element.to_document_string

  render_assertions.contains(html, "Eliminar nota (como admin)")
}

pub fn pin_button_uses_pinned_state_test() {
  let notes = [
    notes_list.NoteView(
      id: 1,
      author: "María García",
      created_at: "14:32",
      content: "Pinned note",
      url: option.None,
      pinned: True,
      can_pin: True,
      pin_in_flight: False,
      pin_disabled_reason: option.None,
      can_delete: False,
      delete_context: DeleteOwnNote,
      author_email: "maria@example.com",
      author_project_role: option.None,
      author_org_role: org_role.Member,
    ),
  ]

  let html =
    notes_list.view(
      notes,
      "Eliminar nota",
      "Eliminar nota (como admin)",
      "Fijar nota",
      "Desfijar nota",
      fn(id) { id },
      fn(id, _pinned) { id },
    )
    |> element.to_document_string

  render_assertions.contains(html, "Desfijar nota")
  render_assertions.contains(html, "data-testid=\"note-pin-action\"")
}

pub fn pin_button_explains_blocked_permission_test() {
  let notes = [
    notes_list.NoteView(
      id: 1,
      author: "Carlos López",
      created_at: "09:15",
      content: "Other note",
      url: option.None,
      pinned: False,
      can_pin: False,
      pin_in_flight: False,
      pin_disabled_reason: option.Some("Solo autor o manager"),
      can_delete: False,
      delete_context: DeleteAsAdmin,
      author_email: "carlos@example.com",
      author_project_role: option.None,
      author_org_role: org_role.Member,
    ),
  ]

  let html =
    notes_list.view(
      notes,
      "Eliminar nota",
      "Eliminar nota (como admin)",
      "Fijar nota",
      "Desfijar nota",
      fn(id) { id },
      fn(id, _pinned) { id },
    )
    |> element.to_document_string

  render_assertions.contains(html, "Solo autor o manager")
  render_assertions.contains(html, "aria-disabled=\"true\"")
}
