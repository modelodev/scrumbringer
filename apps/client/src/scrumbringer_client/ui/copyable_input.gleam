import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element as lelement
import lustre/element/html.{div, input, label, text}

import scrumbringer_client/ui/button

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
      button.text(copy_label, on_copy, button.Secondary, button.EntityAction)
        |> button.view,
    ]),
    case status {
      Some(msg) -> div([attribute.class("hint")], [text(msg)])
      None -> lelement.none()
    },
  ])
}
