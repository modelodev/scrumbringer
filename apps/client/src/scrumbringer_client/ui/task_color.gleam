////
//// Task color helpers.
////

import gleam/option.{type Option, None, Some}

import domain/card.{type CardColor}
import scrumbringer_client/ui/color_picker

/// Returns the CSS class for a card-colored left border.
pub fn card_border_class(card_color: Option(CardColor)) -> String {
  case card_color {
    None -> ""
    Some(color) -> color_picker.border_class(Some(color))
  }
}
