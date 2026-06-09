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

import scrumbringer_client/ui/color_picker.{type CardColor}

// =============================================================================
// Initials Generation
// =============================================================================

/// Generate initials from a card title.
///
/// Rules:
/// 1. Take first character of first 2 words (e.g., "OAuth Implementation" → "OI")
/// 2. If single word, take first 2 characters (e.g., "Refactor" → "RE")
/// 3. Uppercase always
/// 4. Max 2 characters
pub fn generate_initials(title: String) -> String {
  let words =
    title
    |> string.trim
    |> string.split(" ")
    |> list.filter(fn(w) { w != "" })

  case words {
    [] -> "??"
    [single] -> single_word_initials(single)
    [first, second, ..] -> {
      string.uppercase(
        first_grapheme_or(first, "?") <> first_grapheme_or(second, "?"),
      )
    }
  }
}

fn single_word_initials(word: String) -> String {
  case string.to_graphemes(word) {
    [] -> "??"
    [a] -> string.uppercase(a)
    [a, b, ..] -> string.uppercase(a <> b)
  }
}

fn first_grapheme_or(value: String, fallback: String) -> String {
  case string.to_graphemes(value) {
    [first, ..] -> first
    [] -> fallback
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
) -> Element(msg) {
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
pub fn view_color_dot(color: Option(CardColor)) -> Element(msg) {
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
