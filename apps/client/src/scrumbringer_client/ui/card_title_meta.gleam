import gleam/option.{type Option}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import scrumbringer_client/ui/card_meta

pub type Order {
  ColorTitleNotes
  TitleNotesColor
}

pub fn elements(
  title: Element(msg),
  color: Option(String),
  fallback: Option(String),
  has_new_notes: Bool,
  notes_tooltip: String,
  order: Order,
) -> List(Element(msg)) {
  let color_el = card_meta.color_dot(color, fallback)
  let notes_el = card_meta.notes_indicator(has_new_notes, notes_tooltip)

  case order {
    ColorTitleNotes -> [color_el, title, notes_el]
    TitleNotesColor -> [title, notes_el, color_el]
  }
}

pub fn view_with_class(
  class: String,
  title: Element(msg),
  color: Option(String),
  fallback: Option(String),
  has_new_notes: Bool,
  notes_tooltip: String,
  order: Order,
) -> Element(msg) {
  div(
    [attribute.class(class)],
    elements(title, color, fallback, has_new_notes, notes_tooltip, order),
  )
}
