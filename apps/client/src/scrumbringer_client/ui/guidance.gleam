//// Compact guidance for operational screens.

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{dd, div, dl, dt, p, text}

pub type Definition {
  Definition(term: String, description: String)
}

pub fn definition(term: String, description: String) -> Definition {
  Definition(term: term, description: description)
}

pub fn section(message: String) -> Element(msg) {
  p([attribute.class("guidance guidance-section")], [text(message)])
}

pub fn definitions(items: List(Definition)) -> Element(msg) {
  dl(
    [attribute.class("guidance guidance-definitions")],
    list.map(items, view_definition),
  )
}

fn view_definition(item: Definition) -> Element(msg) {
  div([attribute.class("guidance-definition")], [
    dt([attribute.class("guidance-term")], [text(item.term)]),
    dd([attribute.class("guidance-description")], [
      text(item.description),
    ]),
  ])
}
