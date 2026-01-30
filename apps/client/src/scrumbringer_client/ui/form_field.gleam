import lustre/attribute
import lustre/element as lelement
import lustre/element/html.{div, label, text}

pub fn view(
  label_text: String,
  control: lelement.Element(msg),
) -> lelement.Element(msg) {
  div([attribute.class("field")], [
    label([], [text(label_text)]),
    control,
  ])
}

pub fn with_hint(
  label_text: String,
  control: lelement.Element(msg),
  hint: String,
) -> lelement.Element(msg) {
  div([attribute.class("field")], [
    label([], [text(label_text)]),
    control,
    div([attribute.class("hint")], [text(hint)]),
  ])
}

pub fn hint(hint: String) -> lelement.Element(msg) {
  div([attribute.class("hint")], [text(hint)])
}

pub fn none() -> lelement.Element(msg) {
  lelement.none()
}
