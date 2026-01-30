import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{span, text}

pub fn color_dot(
  color: Option(String),
  fallback: Option(String),
) -> Element(msg) {
  let style = case color, fallback {
    Some(hex), _ -> Some("background-color: " <> hex <> ";")
    None, Some(fallback_color) ->
      Some("background-color: " <> fallback_color <> ";")
    None, None -> None
  }

  case style {
    Some(value) ->
      span(
        [attribute.class("card-color-dot"), attribute.attribute("style", value)],
        [],
      )
    None -> none()
  }
}

pub fn notes_indicator(has_new_notes: Bool, tooltip: String) -> Element(msg) {
  case has_new_notes {
    True ->
      span(
        [
          attribute.class("card-notes-indicator tooltip-trigger"),
          attribute.attribute("data-testid", "card-notes-indicator"),
          attribute.attribute("data-tooltip", tooltip),
        ],
        [text("[!]")],
      )
    False -> none()
  }
}
