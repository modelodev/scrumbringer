//// Notes list UI view.
////
//// AC1: Detect URLs in text, make clickable
//// AC2: GitHub links (PR, Issue, Commit) show icon and short path
//// AC3: Notes with PR links are highlighted (green border)

import domain/link_detection
import domain/org_role
import domain/project_role
import gleam/list
import gleam/option.{type Option}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, p, span, text}

import scrumbringer_client/ui/button
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/note_content
import scrumbringer_client/ui/tooltips/types.{
  type DeleteNoteContext, DeleteAsAdmin, DeleteOwnNote,
}

pub type NoteView {
  NoteView(
    id: Int,
    author: String,
    created_at: String,
    content: String,
    url: Option(String),
    pinned: Bool,
    can_pin: Bool,
    pin_in_flight: Bool,
    pin_disabled_reason: Option(String),
    can_delete: Bool,
    delete_context: DeleteNoteContext,
    author_email: String,
    author_project_role: Option(project_role.ProjectRole),
    author_org_role: org_role.OrgRole,
  )
}

pub fn view(
  notes: List(NoteView),
  delete_label: String,
  delete_admin_label: String,
  pin_label: String,
  unpin_label: String,
  on_delete: fn(Int) -> msg,
  on_pin_toggle: fn(Int, Bool) -> msg,
) -> Element(msg) {
  div(
    [attribute.class("notes-list")],
    list.map(notes, fn(note) {
      view_note(
        note,
        delete_label,
        delete_admin_label,
        pin_label,
        unpin_label,
        on_delete,
        on_pin_toggle,
      )
    }),
  )
}

fn view_note(
  note: NoteView,
  delete_label: String,
  delete_admin_label: String,
  pin_label: String,
  unpin_label: String,
  on_delete: fn(Int) -> msg,
  on_pin_toggle: fn(Int, Bool) -> msg,
) -> Element(msg) {
  let NoteView(
    id: id,
    author: author,
    created_at: created_at,
    content: content,
    url: url,
    pinned: pinned,
    can_pin: can_pin,
    pin_in_flight: pin_in_flight,
    pin_disabled_reason: pin_disabled_reason,
    can_delete: can_delete,
    delete_context: delete_context,
    author_email: author_email,
    author_project_role: author_project_role,
    author_org_role: author_org_role,
  ) = note

  let actual_delete_label = case delete_context {
    DeleteOwnNote -> delete_label
    DeleteAsAdmin -> delete_admin_label
  }

  let author_role_label = case author_project_role {
    option.Some(role) -> project_role.to_string(role)
    option.None -> org_role.to_string(author_org_role)
  }

  // AC20: Tooltip text shows full email and role
  let tooltip_text = author_email <> " (" <> author_role_label <> ")"

  // AC1, AC2, AC3: Detect links and check for PR
  let segments = link_detection.detect_links(content)
  let has_pr = link_detection.has_pr_link(segments)

  // AC3: PR notes get green border highlight
  let note_class = case has_pr {
    True -> "note-item note-delivery"
    False -> "note-item"
  }

  div([attribute.class(note_class)], [
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
      view_pin_button(
        id,
        pinned,
        can_pin,
        pin_in_flight,
        pin_disabled_reason,
        pin_label,
        unpin_label,
        on_pin_toggle,
      ),
      case can_delete {
        True ->
          button.icon(
            actual_delete_label,
            on_delete(id),
            icons.Trash,
            button.Danger,
            button.EntityAction,
          )
          |> button.with_size(button.ExtraSmall)
          |> button.view
        False -> element.none()
      },
    ]),
    p([attribute.class("note-content")], note_content.view(content, url)),
  ])
}

fn view_pin_button(
  id: Int,
  pinned: Bool,
  can_pin: Bool,
  pin_in_flight: Bool,
  pin_disabled_reason: Option(String),
  pin_label: String,
  unpin_label: String,
  on_pin_toggle: fn(Int, Bool) -> msg,
) -> Element(msg) {
  let label = case pinned {
    True -> unpin_label
    False -> pin_label
  }
  let icon = case pinned {
    True -> icons.Star
    False -> icons.StarOutline
  }
  let button =
    button.icon(
      label,
      on_pin_toggle(id, !pinned),
      icon,
      button.Ghost,
      button.EntityAction,
    )
    |> button.with_size(button.ExtraSmall)
    |> button.with_testid("note-pin-action")

  case can_pin, pin_disabled_reason {
    True, _ -> button |> button.with_disabled(pin_in_flight) |> button.view
    False, option.Some(reason) ->
      button
      |> button.with_blocked_reason(reason)
      |> button.view
    False, option.None -> element.none()
  }
}
