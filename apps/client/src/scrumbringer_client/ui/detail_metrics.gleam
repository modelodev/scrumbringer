//// Shared helpers for detail metrics sections.

import domain/metrics
import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/ui/badge

/// Format duration in seconds to compact text (e.g. "1h 20m").
pub fn format_duration_s(seconds: Int) -> String {
  let total = case seconds < 0 {
    True -> 0
    False -> seconds
  }
  let hours = total / 3600
  let rem_hour = total - hours * 3600
  let mins = rem_hour / 60
  let secs = rem_hour - mins * 60
  case hours > 0 {
    True -> int.to_string(hours) <> "h " <> int.to_string(mins) <> "m"
    False ->
      case mins > 0 {
        True -> int.to_string(mins) <> "m " <> int.to_string(secs) <> "s"
        False -> int.to_string(secs) <> "s"
      }
  }
}

/// Render a two-column metrics row.
pub fn view_row(label: String, value: String) -> Element(msg) {
  div([attribute.class("detail-row")], [
    span([attribute.class("detail-label")], [text(label)]),
    span([attribute.class("detail-value")], [text(value)]),
  ])
}

/// Render workflows breakdown list used by detail metrics tabs.
pub fn view_workflows(
  label: String,
  empty_label: String,
  workflows: List(metrics.WorkflowBreakdown),
) -> Element(msg) {
  div([attribute.class("milestone-workflows")], [
    span([attribute.class("detail-label")], [text(label)]),
    div([attribute.class("metrics-workflow-list")], [
      case workflows {
        [] ->
          div([attribute.class("metrics-workflow-empty")], [text(empty_label)])
        _ ->
          div(
            [attribute.class("metrics-workflow-items")],
            list.map(workflows, fn(item) {
              div([attribute.class("metrics-workflow-item")], [
                span([attribute.class("metrics-workflow-name")], [
                  text(item.name),
                ]),
                badge.quick(int.to_string(item.count), badge.Primary),
              ])
            }),
          )
      },
    ]),
  ])
}
