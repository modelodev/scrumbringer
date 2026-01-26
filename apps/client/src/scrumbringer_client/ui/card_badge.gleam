//// Card initials badge component.
////
//// ## Mission
////
//// Provides a visual badge showing card initials with color background.
////
//// ## Responsibilities
////
//// - Generate initials from card title
//// - Render badge with appropriate color
////
//// ## Relations
////
//// - **features/pool/view.gleam**: Uses badge on task cards
//// - **features/my_bar/view.gleam**: Uses badge in card group headers

import gleam/list
import gleam/option.{type Option}
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import scrumbringer_client/client_state.{type Msg}
import scrumbringer_client/ui/color_picker.{type CardColor}

// =============================================================================
// Initials Generation
// =============================================================================

// Justification: nested case improves clarity for branching logic.
/// Generate initials from a card title.
///
/// Rules:
/// 1. Take first character of first 2 words (e.g., "OAuth Implementation" → "OI")
/// 2. If single word, take first 2 characters (e.g., "Refactor" → "RE")
/// 3. Uppercase always
/// 4. Max 2 characters
/// Justification: nested case improves clarity for branching logic.
pub fn generate_initials(title: String) -> String {
  let words =
    title
    |> string.trim
    |> string.split(" ")
    |> list.filter(fn(w) { w != "" })

  case words {
    [] -> "??"
    [single] -> {
      let chars = string.to_graphemes(single)
      case chars {
        [] -> "??"
        [a] -> string.uppercase(a)
        [a, b, ..] -> string.uppercase(a <> b)
      }
    }
    [first, second, ..] -> {
      let first_char = case string.to_graphemes(first) {
        [c, ..] -> c
        [] -> "?"
      }
      let second_char = case string.to_graphemes(second) {
        [c, ..] -> c
        [] -> "?"
      }
      string.uppercase(first_char <> second_char)
    }
  }
}

// =============================================================================
// View Functions
// =============================================================================

/// Renders a card initials badge.
///
/// - `title`: Card title to generate initials from
/// - `color`: Card color (None = muted/gray)
/// - `tooltip`: Optional tooltip text (full card title)
pub fn view(
  title: String,
  color: Option(CardColor),
  tooltip: Option(String),
) -> Element(Msg) {
  let initials = generate_initials(title)
  let color_class = color_picker.initials_class(color)

  let tooltip_attr = case tooltip {
    option.Some(t) -> [attribute.attribute("title", t)]
    option.None -> []
  }

  span(
    list.flatten([
      [
        attribute.class("card-initials-badge " <> color_class),
        attribute.attribute("aria-label", title),
      ],
      tooltip_attr,
    ]),
    [text(initials)],
  )
}

/// Renders a small card color indicator (just the dot, no initials).
pub fn view_color_dot(color: Option(CardColor)) -> Element(Msg) {
  case color {
    option.None -> element.none()
    option.Some(c) ->
      span(
        [
          attribute.class("color-picker-swatch"),
          attribute.attribute(
            "style",
            "background: " <> color_picker.css_var(c),
          ),
        ],
        [],
      )
  }
}
