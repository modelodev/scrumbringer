//// Tests for notes list delete context (AC19).

import gleam/option
import gleam/string
import lustre/element

import domain/org_role
import domain/project_role
import scrumbringer_client/ui/notes_list
import scrumbringer_client/ui/tooltips/types.{DeleteAsAdmin, DeleteOwnNote}

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

fn assert_not_contains(html: String, text: String) {
  let assert False = string.contains(html, text)
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

  assert_contains(html, "Eliminar nota")
  assert_not_contains(html, "(como admin)")
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

  assert_contains(html, "Eliminar nota (como admin)")
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

  assert_contains(html, "Desfijar nota")
  assert_contains(html, "data-testid=\"note-pin-action\"")
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

  assert_contains(html, "Solo autor o manager")
  assert_contains(html, "aria-disabled=\"true\"")
}
