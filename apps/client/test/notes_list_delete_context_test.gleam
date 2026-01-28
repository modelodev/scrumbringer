//// Tests for notes list delete context (AC19).

import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/tooltips/types.{DeleteAsAdmin, DeleteOwnNote}

pub fn delete_button_shows_own_note_label_test() {
  let notes = [
    notes_list.NoteView(
      id: 1,
      author: "María García",
      created_at: "14:32",
      content: "Test note",
      can_delete: True,
      delete_context: DeleteOwnNote,
      author_email: "maria@example.com",
      author_role: "Member",
    ),
  ]

  let html =
    notes_list.view(
      notes,
      "Eliminar nota",
      "Eliminar nota (como admin)",
      fn(id) { id },
    )
    |> element.to_document_string

  string.contains(html, "Eliminar nota") |> should.be_true
  string.contains(html, "(como admin)") |> should.be_false
}

pub fn delete_button_shows_admin_context_test() {
  let notes = [
    notes_list.NoteView(
      id: 1,
      author: "Carlos López",
      created_at: "09:15",
      content: "Another note",
      can_delete: True,
      delete_context: DeleteAsAdmin,
      author_email: "carlos@example.com",
      author_role: "Developer",
    ),
  ]

  let html =
    notes_list.view(
      notes,
      "Eliminar nota",
      "Eliminar nota (como admin)",
      fn(id) { id },
    )
    |> element.to_document_string

  string.contains(html, "Eliminar nota (como admin)") |> should.be_true
}
