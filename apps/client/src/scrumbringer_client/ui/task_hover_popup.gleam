////
//// Pool task hover popup.
////

import gleam/list as g_list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, span, text}
import lustre/event

pub type TaskHoverConfig(msg) {
  TaskHoverConfig(
    card_label: String,
    card_title: Option(String),
    age_label: String,
    age_value: String,
    description_label: String,
    description: String,
    open_label: String,
    on_open: msg,
  )
}

pub fn view(config: TaskHoverConfig(msg)) -> Element(msg) {
  let TaskHoverConfig(
    card_label: card_label,
    card_title: card_title,
    age_label: age_label,
    age_value: age_value,
    description_label: description_label,
    description: description,
    open_label: open_label,
    on_open: on_open,
  ) = config

  let card_entries = case card_title {
    Some(title) -> [
      span([attribute.class("task-preview-label")], [text(card_label)]),
      span([attribute.class("task-preview-value")], [text(title)]),
    ]
    None -> []
  }

  let age_entries = [
    span([attribute.class("task-preview-label")], [text(age_label)]),
    span([attribute.class("task-preview-value")], [text(age_value)]),
  ]

  let description_entries = case string.is_empty(description) {
    True -> []
    False -> [
      span([attribute.class("task-preview-label")], [
        text(description_label),
      ]),
      span([attribute.class("task-preview-value task-preview-description")], [
        text(description),
      ]),
    ]
  }

  let grid_entries =
    g_list.append(g_list.append(card_entries, age_entries), description_entries)

  div(
    [
      attribute.class("task-card-preview"),
      attribute.attribute("role", "tooltip"),
    ],
    [
      div([attribute.class("task-preview-grid")], grid_entries),
      div([attribute.class("task-preview-actions")], [
        button(
          [
            attribute.class("task-preview-link"),
            event.on_click(on_open),
          ],
          [text(open_label)],
        ),
      ]),
    ],
  )
}
