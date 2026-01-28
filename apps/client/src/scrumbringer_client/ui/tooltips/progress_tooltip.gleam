//// Progress tooltip for progress bar (AC18).

import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/ui/tooltips/types.{type ProgressBreakdown}

pub type Labels {
  Labels(
    progress: String,
    completed: String,
    in_progress: String,
    pending: String,
  )
}

pub type Config(msg) {
  Config(data: ProgressBreakdown, labels: Labels)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let Config(data: data, labels: labels) = config
  let types.ProgressBreakdown(
    completed: completed,
    in_progress: in_progress,
    pending: pending,
    percentage: percentage,
  ) = data

  div([attribute.class("progress-tooltip"), attribute.role("tooltip")], [
    div([attribute.class("progress-tooltip-header")], [
      text(labels.progress <> " " <> int.to_string(percentage) <> "%"),
    ]),
    div([attribute.class("progress-tooltip-breakdown")], [
      div([attribute.class("progress-tooltip-item completed")], [
        span([attribute.class("progress-icon")], [text("●")]),
        text(" " <> int.to_string(completed) <> " " <> labels.completed),
      ]),
      div([attribute.class("progress-tooltip-item in-progress")], [
        span([attribute.class("progress-icon")], [text("◐")]),
        text(" " <> int.to_string(in_progress) <> " " <> labels.in_progress),
      ]),
      div([attribute.class("progress-tooltip-item pending")], [
        span([attribute.class("progress-icon")], [text("○")]),
        text(" " <> int.to_string(pending) <> " " <> labels.pending),
      ]),
    ]),
  ])
}
