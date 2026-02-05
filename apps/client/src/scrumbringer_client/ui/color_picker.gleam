//// Color picker dropdown component for card colors.
////
//// ## Mission
////
//// Provides a dropdown selector for choosing card colors.
////
//// ## Responsibilities
////
//// - Render dropdown trigger with current color swatch
//// - Show dropdown menu with all color options
//// - Handle selection and click-outside closing
////
//// ## Relations
////
//// - **features/admin/cards.gleam**: Uses this for card color selection
//// - **features/fichas/card_detail.gleam**: Uses this for viewing card color

import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/event

import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Types
// =============================================================================

/// Available card colors.
pub type CardColor {
  Gray
  Red
  Orange
  Yellow
  Green
  Blue
  Purple
  Pink
}

/// All available colors in order.
pub const all_colors = [Gray, Red, Orange, Yellow, Green, Blue, Purple, Pink]

// =============================================================================
// Color Utilities
// =============================================================================

/// Convert color to its string value (for API/storage).
pub fn color_to_string(color: CardColor) -> String {
  case color {
    Gray -> "gray"
    Red -> "red"
    Orange -> "orange"
    Yellow -> "yellow"
    Green -> "green"
    Blue -> "blue"
    Purple -> "purple"
    Pink -> "pink"
  }
}

/// Parse a string to CardColor (returns None for invalid/empty).
pub fn string_to_color(s: String) -> Option(CardColor) {
  case s {
    "gray" -> Some(Gray)
    "red" -> Some(Red)
    "orange" -> Some(Orange)
    "yellow" -> Some(Yellow)
    "green" -> Some(Green)
    "blue" -> Some(Blue)
    "purple" -> Some(Purple)
    "pink" -> Some(Pink)
    _ -> None
  }
}

/// Get the CSS class for a color border.
pub fn border_class(color: Option(CardColor)) -> String {
  case color {
    None -> ""
    Some(c) -> "card-border-" <> color_to_string(c)
  }
}

/// Get the CSS class for initials badge background.
pub fn initials_class(color: Option(CardColor)) -> String {
  case color {
    None -> "card-initials-none"
    Some(c) -> "card-initials-" <> color_to_string(c)
  }
}

/// Get the CSS variable name for a color.
pub fn css_var(color: CardColor) -> String {
  "var(--sb-card-" <> color_to_string(color) <> ")"
}

/// Get a color circle emoji for display in selects/text.
pub fn color_emoji(color: CardColor) -> String {
  case color {
    Gray -> "⚪"
    Red -> "🔴"
    Orange -> "🟠"
    Yellow -> "🟡"
    Green -> "🟢"
    Blue -> "🔵"
    Purple -> "🟣"
    Pink -> "🩷"
  }
}

/// Get the i18n key for a color.
pub fn color_i18n_key(color: CardColor) -> i18n_text.Text {
  case color {
    Gray -> i18n_text.ColorGray
    Red -> i18n_text.ColorRed
    Orange -> i18n_text.ColorOrange
    Yellow -> i18n_text.ColorYellow
    Green -> i18n_text.ColorGreen
    Blue -> i18n_text.ColorBlue
    Purple -> i18n_text.ColorPurple
    Pink -> i18n_text.ColorPink
  }
}

// =============================================================================
// View Functions
// =============================================================================

/// Renders a color swatch (circular indicator).
pub fn view_swatch(color: Option(CardColor)) -> Element(Msg) {
  case color {
    None ->
      span(
        [
          attribute.class("color-picker-swatch color-picker-swatch-none"),
        ],
        [],
      )
    Some(c) ->
      span(
        [
          attribute.class("color-picker-swatch"),
          attribute.attribute("style", "background: " <> css_var(c)),
        ],
        [],
      )
  }
}

/// Renders the color picker dropdown.
///
/// - `model`: Current model for i18n
/// - `selected`: Currently selected color (None = no color)
/// - `is_open`: Whether dropdown is open
/// - `on_toggle`: Message to toggle dropdown
/// - `on_select`: Message factory for selecting a color
pub fn view(
  model: Model,
  selected: Option(CardColor),
  is_open: Bool,
  on_toggle: Msg,
  on_select: fn(Option(CardColor)) -> Msg,
) -> Element(Msg) {
  let open_class = case is_open {
    True -> " open"
    False -> ""
  }

  let selected_label = case selected {
    None -> helpers_i18n.i18n_t(model, i18n_text.ColorNone)
    Some(c) -> helpers_i18n.i18n_t(model, color_i18n_key(c))
  }

  div(
    [
      attribute.class("color-picker" <> open_class),
    ],
    [
      // Trigger button
      div(
        [
          attribute.class("color-picker-trigger"),
          attribute.attribute("role", "combobox"),
          attribute.attribute("aria-expanded", case is_open {
            True -> "true"
            False -> "false"
          }),
          attribute.attribute(
            "aria-label",
            helpers_i18n.i18n_t(model, i18n_text.ColorLabel),
          ),
          event.on_click(on_toggle),
        ],
        [
          view_swatch(selected),
          span([attribute.class("color-picker-label")], [text(selected_label)]),
          span([attribute.class("color-picker-arrow")], [text("▼")]),
        ],
      ),
      // Dropdown menu
      div(
        [
          attribute.class("color-picker-dropdown"),
          attribute.attribute("role", "listbox"),
        ],
        [
          // "None" option
          view_color_option(model, None, selected, on_select),
          // Color options
          ..list.map(all_colors, fn(c) {
            view_color_option(model, Some(c), selected, on_select)
          })
        ],
      ),
    ],
  )
}

fn view_color_option(
  model: Model,
  color: Option(CardColor),
  selected: Option(CardColor),
  on_select: fn(Option(CardColor)) -> Msg,
) -> Element(Msg) {
  let is_selected = color == selected

  let label = case color {
    None -> helpers_i18n.i18n_t(model, i18n_text.ColorNone)
    Some(c) -> helpers_i18n.i18n_t(model, color_i18n_key(c))
  }

  let selected_class = case is_selected {
    True -> " selected"
    False -> ""
  }

  div(
    [
      attribute.class("color-picker-option" <> selected_class),
      attribute.attribute("role", "option"),
      attribute.attribute("aria-selected", case is_selected {
        True -> "true"
        False -> "false"
      }),
      event.on_click(on_select(color)),
    ],
    [view_swatch(color), span([], [text(label)])],
  )
}
