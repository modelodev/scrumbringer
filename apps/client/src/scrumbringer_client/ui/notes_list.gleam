//// Notes list UI view.
////
//// AC1: Detect URLs in text, make clickable
//// AC2: GitHub links (PR, Issue, Commit) show icon and short path
//// AC3: Notes with PR links are highlighted (green border)

import domain/link_detection.{
  type DetectedLink, type TextSegment, DetectedLink, GenericUrl, GitHubCommit,
  GitHubIssue, GitHubPR, Link, PlainText,
}
import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html.{a, button, div, p, span, text}
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
    p([attribute.class("note-content")], render_segments(segments)),
  ])
}

// =============================================================================
// Link Rendering (AC1, AC2)
// =============================================================================

fn render_segments(segments: List(TextSegment)) -> List(Element(msg)) {
  list.map(segments, render_segment)
}

fn render_segment(segment: TextSegment) -> Element(msg) {
  case segment {
    PlainText(content) -> text(content)
    Link(link) -> render_link(link)
  }
}

fn render_link(link: DetectedLink) -> Element(msg) {
  let DetectedLink(
    url: url,
    link_type: link_type,
    display_text: display_text,
    ..,
  ) = link

  let attrs = link_attrs(url)

  case link_type {
    GitHubPR(..) | GitHubIssue(..) | GitHubCommit(..) ->
      // AC2: GitHub links with icon
      span([attribute.class("github-link")], [
        icons.nav_icon(icons.GitHub, icons.XSmall),
        a(attrs, [text(display_text)]),
      ])
    GenericUrl ->
      // AC1: Generic clickable link
      a(attrs, [text(display_text)])
  }
}

fn link_attrs(url: String) -> List(Attribute(msg)) {
  [
    attribute.href(url),
    attribute.target("_blank"),
    attribute.rel("noopener noreferrer"),
    attribute.class("note-link"),
  ]
}
