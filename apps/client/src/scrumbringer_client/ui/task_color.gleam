////
//// Task color helpers.
////

import gleam/option.{type Option, None, Some}

import scrumbringer_client/ui/color_picker

/// Returns the CSS class for a card-colored left border.
pub fn card_border_class(card_color: Option(String)) -> String {
  case card_color {
    None -> ""
    Some(color) -> {
      let parsed = color_picker.string_to_color(color)
      color_picker.border_class(parsed)
    }
  }
}
