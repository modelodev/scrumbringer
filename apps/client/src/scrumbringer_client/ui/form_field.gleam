import gleam/option as opt
import lustre/attribute
import lustre/element as lelement
import lustre/element/html.{div, label, span, text}

pub fn view(
  label_text: String,
  control: lelement.Element(msg),
) -> lelement.Element(msg) {
  div([attribute.class("field")], [
    label([], [text(label_text)]),
    control,
  ])
}

pub fn view_required(
  label_text: String,
  control: lelement.Element(msg),
) -> lelement.Element(msg) {
  div([attribute.class("field")], [
    label([], [
      text(label_text),
      span(
        [
          attribute.class("required-indicator"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("*")],
      ),
    ]),
    control,
  ])
}

pub fn with_error(
  label_text: String,
  control: lelement.Element(msg),
  error: opt.Option(String),
) -> lelement.Element(msg) {
  div([attribute.class("field")], [
    label([], [
      text(label_text),
      span(
        [
          attribute.class("required-indicator"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("*")],
      ),
    ]),
    control,
    case error {
      opt.Some(message) ->
        div([attribute.class("field-error"), attribute.role("alert")], [
          span([attribute.class("error-icon")], [text("!")]),
          text(message),
        ])
      opt.None -> lelement.none()
    },
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
