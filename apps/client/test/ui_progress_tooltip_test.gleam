//// Tests for progress tooltip (AC18).

import gleam/string
import lustre/element

import scrumbringer_client/ui/tooltips/progress_tooltip
import scrumbringer_client/ui/tooltips/types.{ProgressBreakdown}

fn assert_contains(html: String, text: String) {
  let assert True = string.contains(html, text)
}

pub fn shows_breakdown_test() {
  let config =
    progress_tooltip.Config(
      data: ProgressBreakdown(
        closed: 3,
        in_progress: 1,
        pending: 1,
        percentage: 60,
      ),
      labels: progress_tooltip.Labels(
        progress: "Progreso:",
        closed: "cerradas",
        in_progress: "en curso",
        pending: "pendientes",
      ),
    )

  let html = progress_tooltip.view(config) |> element.to_document_string

  assert_contains(html, "3")
  assert_contains(html, "cerradas")
  assert_contains(html, "1")
  assert_contains(html, "en curso")
  assert_contains(html, "pendientes")
}

pub fn calculates_percentage_display_test() {
  let config =
    progress_tooltip.Config(
      data: ProgressBreakdown(
        closed: 3,
        in_progress: 1,
        pending: 1,
        percentage: 60,
      ),
      labels: progress_tooltip.Labels(
        progress: "Progreso:",
        closed: "cerradas",
        in_progress: "en curso",
        pending: "pendientes",
      ),
    )

  let html = progress_tooltip.view(config) |> element.to_document_string

  assert_contains(html, "Progreso:")
  assert_contains(html, "60%")
}

pub fn handles_zero_tasks_test() {
  let config =
    progress_tooltip.Config(
      data: ProgressBreakdown(
        closed: 0,
        in_progress: 0,
        pending: 0,
        percentage: 0,
      ),
      labels: progress_tooltip.Labels(
        progress: "Progreso:",
        closed: "cerradas",
        in_progress: "en curso",
        pending: "pendientes",
      ),
    )

  let html = progress_tooltip.view(config) |> element.to_document_string

  assert_contains(html, "0")
  assert_contains(html, "cerradas")
}
