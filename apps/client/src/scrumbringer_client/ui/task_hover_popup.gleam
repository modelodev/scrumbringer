////
//// Pool task hover popup.
////

import gleam/list as g_list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element as lustre_element
import lustre/element/html.{div, li, span, text, ul}

import scrumbringer_client/ui/button

pub type TaskHoverConfig(msg) {
  TaskHoverConfig(
    card_label: String,
    card_title: Option(String),
    status_label: String,
    status_value: String,
    status_hint: String,
    next_action_label: String,
    next_action_value: String,
    age_label: String,
    age_value: String,
    description_label: String,
    description: String,
    blocked_label: Option(String),
    blocked_items: List(String),
    blocked_hidden_note: Option(String),
    notes_label: Option(String),
    notes: List(HoverNote),
    open_label: String,
    on_open: msg,
  )
}

pub type HoverNote {
  HoverNote(author: String, created_at: String, content: String)
}

pub fn view(config: TaskHoverConfig(msg)) -> lustre_element.Element(msg) {
  let TaskHoverConfig(
    card_label: card_label,
    card_title: card_title,
    status_label: status_label,
    status_value: status_value,
    status_hint: status_hint,
    next_action_label: next_action_label,
    next_action_value: next_action_value,
    age_label: age_label,
    age_value: age_value,
    description_label: description_label,
    description: description,
    blocked_label: blocked_label,
    blocked_items: blocked_items,
    blocked_hidden_note: blocked_hidden_note,
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

  let status_entries = [
    span([attribute.class("task-preview-label task-preview-label-strong")], [
      text(status_label),
    ]),
    span(
      [
        attribute.class("task-preview-value"),
        attribute.attribute("title", status_hint),
      ],
      [text(status_value)],
    ),
    span([attribute.class("task-preview-label task-preview-label-strong")], [
      text(next_action_label),
    ]),
    span([attribute.class("task-preview-value")], [text(next_action_value)]),
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
    g_list.append(
      g_list.append(g_list.append(card_entries, status_entries), age_entries),
      description_entries,
    )

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
        case blocked_hidden_note {
          Some(note) ->
            span([attribute.class("task-preview-blocked-hidden-note")], [
              text(note),
            ])
          None -> lustre_element.none()
        },
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
        button.text(open_label, on_open, button.Secondary, button.EntityAction)
        |> button.with_size(button.ExtraSmall)
        |> button.with_class("task-preview-btn")
        |> button.view,
      ]),
    ],
  )
}
