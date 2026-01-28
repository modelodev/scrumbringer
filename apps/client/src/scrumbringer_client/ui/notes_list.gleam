//// Notes list UI view.

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, p, span, text}
import lustre/event

import scrumbringer_client/ui/icons
import scrumbringer_client/ui/tooltips/types.{
  type DeleteNoteContext, DeleteAsAdmin, DeleteOwnNote,
}

pub type NoteView {
  NoteView(
    id: Int,
    author: String,
    created_at: String,
    content: String,
    can_delete: Bool,
    delete_context: DeleteNoteContext,
    author_email: String,
    author_role: String,
  )
}

pub fn view(
  notes: List(NoteView),
  delete_label: String,
  delete_admin_label: String,
  on_delete: fn(Int) -> msg,
) -> Element(msg) {
  div(
    [attribute.class("notes-list")],
    list.map(notes, fn(note) {
      view_note(note, delete_label, delete_admin_label, on_delete)
    }),
  )
}

fn view_note(
  note: NoteView,
  delete_label: String,
  delete_admin_label: String,
  on_delete: fn(Int) -> msg,
) -> Element(msg) {
  let NoteView(
    id: id,
    author: author,
    created_at: created_at,
    content: content,
    can_delete: can_delete,
    delete_context: delete_context,
    author_email: author_email,
    author_role: author_role,
  ) = note

  let actual_delete_label = case delete_context {
    DeleteOwnNote -> delete_label
    DeleteAsAdmin -> delete_admin_label
  }

  // AC20: Tooltip text shows full email and role
  let tooltip_text = author_email <> " (" <> author_role <> ")"

  div([attribute.class("note-item")], [
    div([attribute.class("note-header")], [
      // AC20: Author with CSS tooltip showing full email + role
      span(
        [
          attribute.class("note-author tooltip-trigger"),
          attribute.attribute("data-tooltip", tooltip_text),
        ],
        [text(author)],
      ),
      span([attribute.class("note-date")], [text(created_at)]),
      case can_delete {
        True ->
          button(
            [
              attribute.class("btn-xs btn-icon"),
              attribute.attribute("title", actual_delete_label),
              attribute.attribute("aria-label", actual_delete_label),
              event.on_click(on_delete(id)),
            ],
            [icons.nav_icon(icons.Trash, icons.Small)],
          )
        False -> element.none()
      },
    ]),
    p([attribute.class("note-content")], [text(content)]),
  ])
}
