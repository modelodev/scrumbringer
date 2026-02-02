////
//// Pool task hover popup.
////

import gleam/list as g_list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, li, span, text, ul}
import lustre/event

pub type TaskHoverConfig(msg) {
  TaskHoverConfig(
    card_label: String,
    card_title: Option(String),
    age_label: String,
    age_value: String,
    description_label: String,
    description: String,
    blocked_label: Option(String),
    blocked_items: List(String),
    notes_label: Option(String),
    notes: List(HoverNote),
    open_label: String,
    on_open: msg,
  )
}

pub type HoverNote {
  HoverNote(author: String, created_at: String, content: String)
}

pub fn view(config: TaskHoverConfig(msg)) -> Element(msg) {
  let TaskHoverConfig(
    card_label: card_label,
    card_title: card_title,
    age_label: age_label,
    age_value: age_value,
    description_label: description_label,
    description: description,
    blocked_label: blocked_label,
    blocked_items: blocked_items,
    notes_label: notes_label,
    notes: notes,
    open_label: open_label,
    on_open: on_open,
  ) = config

  let card_entries = case card_title {
    Some(title) -> [
      span([attribute.class("task-preview-label task-preview-label-strong")], [
        text(card_label),
      ]),
      span([attribute.class("task-preview-value")], [text(title)]),
    ]
    None -> []
  }

  let age_entries = [
    span([attribute.class("task-preview-label task-preview-label-strong")], [
      text(age_label),
    ]),
    span([attribute.class("task-preview-value")], [text(age_value)]),
  ]

  let description_entries = case string.is_empty(description) {
    True -> []
    False -> [
      span([attribute.class("task-preview-label task-preview-label-strong")], [
        text(description_label),
      ]),
      span([attribute.class("task-preview-value task-preview-description")], [
        text(description),
      ]),
    ]
  }

  let grid_entries =
    g_list.append(g_list.append(card_entries, age_entries), description_entries)

  let blocked_section = case blocked_label, blocked_items {
    Some(label), [_, ..] -> [
      div([attribute.class("task-preview-section")], [
        span([attribute.class("task-preview-section-title")], [text(label)]),
        ul(
          [attribute.class("task-preview-list task-preview-blocked-list")],
          g_list.map(blocked_items, fn(item) {
            li([attribute.class("task-preview-list-item")], [
              span([attribute.class("task-preview-blocked-item")], [text(item)]),
            ])
          }),
        ),
      ]),
    ]
    _, _ -> []
  }

  let notes_section = case notes_label, notes {
    Some(label), [_, ..] -> [
      div([attribute.class("task-preview-section")], [
        span([attribute.class("task-preview-section-title")], [text(label)]),
        ul(
          [attribute.class("task-preview-list task-preview-notes")],
          g_list.map(notes, fn(note) {
            let HoverNote(
              author: author,
              created_at: created_at,
              content: content,
            ) = note
            li([attribute.class("task-preview-list-item")], [
              div([attribute.class("task-preview-note")], [
                span([attribute.class("task-preview-note-meta")], [
                  text(author <> " · " <> created_at),
                ]),
                span([attribute.class("task-preview-note-content")], [
                  text(content),
                ]),
              ]),
            ])
          }),
        ),
      ]),
    ]
    _, _ -> []
  }

  let extras = g_list.append(blocked_section, notes_section)

  div(
    [
      attribute.class("task-card-preview"),
      attribute.attribute("role", "tooltip"),
    ],
    [
      div([attribute.class("task-preview-grid")], grid_entries),
      div([attribute.class("task-preview-extras")], extras),
      div([attribute.class("task-preview-actions")], [
        button(
          [
            attribute.class("btn btn-secondary btn-xs task-preview-btn"),
            event.on_click(on_open),
          ],
          [text(open_label)],
        ),
      ]),
    ],
  )
}
