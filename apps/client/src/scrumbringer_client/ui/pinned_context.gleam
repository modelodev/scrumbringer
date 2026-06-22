//// Pinned note context section for detail surfaces.

import gleam/int
import gleam/list
import gleam/option.{type Option}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, li, span, text, ul}
import lustre/event

import scrumbringer_client/ui/note_content

pub type PinnedNote {
  PinnedNote(id: Int, content: String, url: Option(String))
}

pub type Config(msg) {
  Config(
    title: String,
    notes: List(PinnedNote),
    open_notes_label: String,
    more_label: fn(Int) -> String,
    on_open_notes: msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.notes {
    [] -> element.none()
    notes -> {
      let visible_notes = list.take(notes, 3)
      let extra_count = list.length(notes) - list.length(visible_notes)

      div([attribute.class("pinned-context")], [
        h3([attribute.class("pinned-context-title")], [text(config.title)]),
        ul(
          [attribute.class("pinned-context-list")],
          list.map(visible_notes, view_note),
        ),
        case extra_count > 0 {
          True ->
            button(
              [
                attribute.class("pinned-context-more"),
                event.on_click(config.on_open_notes),
              ],
              [
                text(config.more_label(extra_count)),
                span([attribute.class("sr-only")], [
                  text(" " <> config.open_notes_label),
                ]),
              ],
            )
          False -> element.none()
        },
      ])
    }
  }
}

fn view_note(note: PinnedNote) -> Element(msg) {
  li(
    [
      attribute.class("pinned-context-item"),
      attribute.attribute("data-note-id", int.to_string(note.id)),
    ],
    note_content.view(note.content, note.url),
  )
}
