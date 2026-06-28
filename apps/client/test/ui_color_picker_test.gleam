import gleam/option as opt
import lustre/element
import support/render_assertions

import domain/card
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/color_picker

pub fn color_picker_view_renders_from_locale_without_root_model_test() {
  let html =
    color_picker.view(locale.En, opt.Some(card.Blue), True, "toggle", fn(_) {
      "select"
    })
    |> element.to_document_string

  render_assertions.contains(html, "color-picker")
  render_assertions.contains(html, "aria-expanded=\"true\"")
  render_assertions.contains(html, "aria-label=\"Color\"")
  render_assertions.contains(html, "Blue")
  render_assertions.contains(html, "None")
}

pub fn color_picker_swatch_is_generic_over_messages_test() {
  let html =
    color_picker.view_swatch(opt.Some(card.Red))
    |> element.to_document_string

  render_assertions.contains(html, "color-picker-swatch")
  render_assertions.contains(html, "var(--sb-card-red)")
}
