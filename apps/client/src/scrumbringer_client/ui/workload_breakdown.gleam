//// Compact operational workload breakdown.

import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{span, text}

import scrumbringer_client/ui/tone

pub type Metric {
  Metric(label: String, compact_label: String, value: Int, tone: tone.Tone)
}

pub fn metric(
  label: String,
  compact_label: String,
  value: Int,
  tone_value: tone.Tone,
) -> Metric {
  Metric(
    label: label,
    compact_label: compact_label,
    value: value,
    tone: tone_value,
  )
}

pub fn view(metrics: List(Metric)) -> Element(msg) {
  span(
    [
      attribute.class("workload-breakdown"),
      attribute.attribute("data-testid", "workload-breakdown"),
    ],
    list.map(metrics, view_metric),
  )
}

fn view_metric(metric: Metric) -> Element(msg) {
  let Metric(label:, compact_label:, value:, tone: tone_value) = metric
  span(
    [
      attribute.class("workload-breakdown-item " <> tone.class_name(tone_value)),
      attribute.attribute("title", label <> ": " <> int.to_string(value)),
    ],
    [
      span([attribute.class("workload-breakdown-value")], [
        text(int.to_string(value)),
      ]),
      text(" "),
      span([attribute.class("workload-breakdown-label")], [
        text(compact_label),
      ]),
    ],
  )
}
