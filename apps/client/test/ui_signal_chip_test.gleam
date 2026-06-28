import gleam/option.{None, Some}
import lustre/element
import support/render_assertions

import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/tone

pub fn metric_chip_renders_value_label_and_tone_test() {
  let html =
    signal_chip.metric("Available", "4", tone.Available)
    |> signal_chip.with_testid("metric-chip")
    |> signal_chip.view
    |> element.to_document_string

  render_assertions.contains(html, "signal-chip available")
  render_assertions.contains(html, "data-testid=\"metric-chip\"")
  render_assertions.contains(html, "signal-chip-value")
  render_assertions.contains(html, "signal-chip-label")
  render_assertions.contains(html, ">4<")
  render_assertions.contains(html, "</span> <span")
  render_assertions.contains(html, ">Available<")
}

pub fn text_chip_renders_label_without_metric_parts_test() {
  let html =
    signal_chip.text("2 blocked", tone.Blocked)
    |> signal_chip.view
    |> element.to_document_string

  render_assertions.contains(html, "signal-chip blocked")
  render_assertions.contains(html, ">2 blocked<")
  render_assertions.not_contains(html, "signal-chip-value")
}

pub fn metric_if_positive_hides_zero_test() {
  let assert None = signal_chip.metric_if_positive("Blocked", 0, tone.Blocked)

  let assert Some(chip) =
    signal_chip.metric_if_positive("Blocked", 2, tone.Blocked)

  let html =
    chip
    |> signal_chip.view
    |> element.to_document_string

  render_assertions.contains(html, ">2<")
}

pub fn custom_class_preserves_view_contract_test() {
  let html =
    signal_chip.metric_int("Blocked", 1, tone.Blocked)
    |> signal_chip.with_class("custom-health-chip")
    |> signal_chip.with_parts("custom-health-value", "custom-health-label")
    |> signal_chip.with_testid("custom-health-chip")
    |> signal_chip.with_title("Blocked: 1")
    |> signal_chip.view
    |> element.to_document_string

  render_assertions.contains(html, "custom-health-chip blocked")
  render_assertions.contains(html, "custom-health-value")
  render_assertions.contains(html, "custom-health-label")
  render_assertions.contains(html, "data-testid=\"custom-health-chip\"")
  render_assertions.contains(html, "title=\"Blocked: 1\"")
}
