import gleam/option.{None, Some}
import gleam/string
import lustre/element

import scrumbringer_client/ui/signal_chip
import scrumbringer_client/ui/tone

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

pub fn metric_chip_renders_value_label_and_tone_test() {
  let html =
    signal_chip.metric("Available", "4", tone.Available)
    |> signal_chip.with_testid("metric-chip")
    |> signal_chip.view
    |> element.to_document_string

  assert_contains(html, "signal-chip available")
  assert_contains(html, "data-testid=\"metric-chip\"")
  assert_contains(html, "signal-chip-value")
  assert_contains(html, "signal-chip-label")
  assert_contains(html, ">4<")
  assert_contains(html, "</span> <span")
  assert_contains(html, ">Available<")
}

pub fn text_chip_renders_label_without_metric_parts_test() {
  let html =
    signal_chip.text("2 blocked", tone.Blocked)
    |> signal_chip.view
    |> element.to_document_string

  assert_contains(html, "signal-chip blocked")
  assert_contains(html, ">2 blocked<")
  assert_not_contains(html, "signal-chip-value")
}

pub fn metric_if_positive_hides_zero_test() {
  let assert None = signal_chip.metric_if_positive("Blocked", 0, tone.Blocked)

  let assert Some(chip) =
    signal_chip.metric_if_positive("Blocked", 2, tone.Blocked)

  let html =
    chip
    |> signal_chip.view
    |> element.to_document_string

  assert_contains(html, ">2<")
}

pub fn custom_class_preserves_view_contract_test() {
  let html =
    signal_chip.metric_int("Blocked", 1, tone.Blocked)
    |> signal_chip.with_class("kanban-health-chip")
    |> signal_chip.with_parts("kanban-health-value", "kanban-health-label")
    |> signal_chip.with_testid("kanban-health-chip")
    |> signal_chip.with_title("Blocked: 1")
    |> signal_chip.view
    |> element.to_document_string

  assert_contains(html, "kanban-health-chip blocked")
  assert_contains(html, "kanban-health-value")
  assert_contains(html, "kanban-health-label")
  assert_contains(html, "data-testid=\"kanban-health-chip\"")
  assert_contains(html, "title=\"Blocked: 1\"")
}
