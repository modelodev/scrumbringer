//// Shared card progress bar and text rendering.
////
//// ## Mission
////
//// Provide consistent progress display for cards across views.

import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type Variant {
  Default
  Compact
}

pub fn view(
  locale: Locale,
  closed: Int,
  total: Int,
  variant: Variant,
) -> Element(msg) {
  let progress_copy = i18n.t(locale, i18n_text.CardProgressCount(closed, total))
  let percent = case total {
    0 -> 0
    _ -> closed * 100 / total
  }

  case variant {
    Default ->
      div([attribute.class("card-progress-row")], [
        div([attribute.class("progress-bar")], [
          div(
            [
              attribute.class("progress-fill"),
              attribute.style("--progress-width", int.to_string(percent) <> "%"),
            ],
            [],
          ),
        ]),
        span([attribute.class("card-progress")], [text(progress_copy)]),
      ])

    Compact ->
      div([attribute.class("card-progress-cell")], [
        div([attribute.class("progress-bar-mini")], [
          div(
            [
              attribute.class("progress-fill-mini"),
              attribute.style("--progress-width", int.to_string(percent) <> "%"),
            ],
            [],
          ),
        ]),
        span([attribute.class("progress-text-mini")], [text(progress_copy)]),
      ])
  }
}
