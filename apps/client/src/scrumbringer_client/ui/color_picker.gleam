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
//// - **features/cards/detail_modal_entry.gleam**: Uses this for viewing card color

import gleam/list
import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/event

import domain/card
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value

// =============================================================================
// Types
// =============================================================================

pub type CardColor =
  card.CardColor

// =============================================================================
// Color Utilities
// =============================================================================

/// Parse a string to CardColor (returns None for invalid/empty).
pub fn string_to_color(s: String) -> Option(CardColor) {
  case card.parse_color(s) {
    Ok(color) -> Some(color)
    Error(_) -> None
  }
}

/// Get the CSS class for a color border.
pub fn border_class(color: Option(CardColor)) -> String {
  case color {
    None -> ""
    Some(c) -> "card-border-" <> card.color_to_string(c)
  }
}

/// Get the CSS class for initials badge background.
pub fn initials_class(color: Option(CardColor)) -> String {
  case color {
    None -> "card-initials-none"
    Some(c) -> "card-initials-" <> card.color_to_string(c)
  }
}

/// Get the CSS variable name for a color.
pub fn css_var(color: CardColor) -> String {
  "var(--sb-card-" <> card.color_to_string(color) <> ")"
}

/// Get a color circle emoji for display in selects/text.
pub fn color_emoji(color: CardColor) -> String {
  case color {
    card.Gray -> "⚪"
    card.Red -> "🔴"
    card.Orange -> "🟠"
    card.Yellow -> "🟡"
    card.Green -> "🟢"
    card.Blue -> "🔵"
    card.Purple -> "🟣"
    card.Pink -> "🩷"
  }
}

/// Get the i18n key for a color.
pub fn color_i18n_key(color: CardColor) -> i18n_text.Text {
  case color {
    card.Gray -> i18n_text.ColorGray
    card.Red -> i18n_text.ColorRed
    card.Orange -> i18n_text.ColorOrange
    card.Yellow -> i18n_text.ColorYellow
    card.Green -> i18n_text.ColorGreen
    card.Blue -> i18n_text.ColorBlue
    card.Purple -> i18n_text.ColorPurple
    card.Pink -> i18n_text.ColorPink
  }
}

// =============================================================================
// View Functions
// =============================================================================

/// Renders a color swatch (circular indicator).
pub fn view_swatch(color: Option(CardColor)) -> Element(msg) {
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
/// - `locale`: Current locale for i18n
/// - `selected`: Currently selected color (None = no color)
/// - `is_open`: Whether dropdown is open
/// - `on_toggle`: Message to toggle dropdown
/// - `on_select`: Message factory for selecting a color
pub fn view(
  locale: Locale,
  selected: Option(CardColor),
  is_open: Bool,
  on_toggle: msg,
  on_select: fn(Option(CardColor)) -> msg,
) -> Element(msg) {
  let open_class = case is_open {
    True -> " open"
    False -> ""
  }

  let selected_label = case selected {
    None -> t(locale, i18n_text.ColorNone)
    Some(c) -> t(locale, color_i18n_key(c))
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
          attribute.attribute("aria-expanded", attribute_value.boolean(is_open)),
          attribute.attribute("aria-label", t(locale, i18n_text.ColorLabel)),
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
          view_color_option(locale, None, selected, on_select),
          // Color options
          ..list.map(card.all_colors, fn(c) {
            view_color_option(locale, Some(c), selected, on_select)
          })
        ],
      ),
    ],
  )
}

fn view_color_option(
  locale: Locale,
  color: Option(CardColor),
  selected: Option(CardColor),
  on_select: fn(Option(CardColor)) -> msg,
) -> Element(msg) {
  let is_selected = color == selected

  let label = case color {
    None -> t(locale, i18n_text.ColorNone)
    Some(c) -> t(locale, color_i18n_key(c))
  }

  let selected_class = case is_selected {
    True -> " selected"
    False -> ""
  }

  div(
    [
      attribute.class("color-picker-option" <> selected_class),
      attribute.attribute("role", "option"),
      attribute.attribute("aria-selected", attribute_value.boolean(is_selected)),
      event.on_click(on_select(color)),
    ],
    [view_swatch(color), span([], [text(label)])],
  )
}

fn t(locale: Locale, key: i18n_text.Text) -> String {
  i18n.t(locale, key)
}
