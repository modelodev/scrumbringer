import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element as lelement
import lustre/element/html.{button, div, input, label, text}
import lustre/event

pub fn view(
  label_text: String,
  value: String,
  on_copy: msg,
  copy_label: String,
  status: Option(String),
) -> lelement.Element(msg) {
  div([attribute.class("field")], [
    label([], [text(label_text)]),
    div([attribute.class("copy")], [
      input([
        attribute.type_("text"),
        attribute.value(value),
        attribute.readonly(True),
      ]),
      button([event.on_click(on_copy)], [text(copy_label)]),
    ]),
    case status {
      Some(msg) -> div([attribute.class("hint")], [text(msg)])
      None -> lelement.none()
    },
  ])
}
