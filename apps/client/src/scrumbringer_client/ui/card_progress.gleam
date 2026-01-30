//// Shared card progress bar and text rendering.
////
//// ## Mission
////
//// Provide consistent progress display for cards across views.

import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

pub type Variant {
  Default
  Compact
}

pub fn view(completed: Int, total: Int, variant: Variant) -> Element(msg) {
  let progress_text = int.to_string(completed) <> "/" <> int.to_string(total)
  let percent = case total {
    0 -> 0
    _ -> completed * 100 / total
  }

  case variant {
    Default ->
      div([attribute.class("card-progress-row")], [
        div([attribute.class("progress-bar")], [
          div(
            [
              attribute.class("progress-fill"),
              attribute.style("width", int.to_string(percent) <> "%"),
            ],
            [],
          ),
        ]),
        span([attribute.class("card-progress")], [text(progress_text)]),
      ])

    Compact ->
      div([attribute.class("card-progress-cell")], [
        div([attribute.class("progress-bar-mini")], [
          div(
            [
              attribute.class("progress-fill-mini"),
              attribute.style("width", int.to_string(percent) <> "%"),
            ],
            [],
          ),
        ]),
        span([attribute.class("progress-text-mini")], [text(progress_text)]),
      ])
  }
}
