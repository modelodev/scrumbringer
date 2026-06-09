import gleam/option as opt
import gleam/string
import lustre/element

import domain/card
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/color_picker

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn color_picker_view_renders_from_locale_without_root_model_test() {
  let html =
    color_picker.view(locale.En, opt.Some(card.Blue), True, "toggle", fn(_) {
      "select"
    })
    |> element.to_document_string

  assert_contains(html, "color-picker")
  assert_contains(html, "aria-expanded=\"true\"")
  assert_contains(html, "aria-label=\"Color\"")
  assert_contains(html, "Blue")
  assert_contains(html, "None")
}

pub fn color_picker_swatch_is_generic_over_messages_test() {
  let html =
    color_picker.view_swatch(opt.Some(card.Red))
    |> element.to_document_string

  assert_contains(html, "color-picker-swatch")
  assert_contains(html, "var(--sb-card-red)")
}
