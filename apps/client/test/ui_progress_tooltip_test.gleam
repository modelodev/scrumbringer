//// Tests for progress tooltip (AC18).

import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/tooltips/progress_tooltip
import scrumbringer_client/ui/tooltips/types.{ProgressBreakdown}

pub fn shows_breakdown_test() {
  let config =
    progress_tooltip.Config(
      data: ProgressBreakdown(
        completed: 3,
        in_progress: 1,
        pending: 1,
        percentage: 60,
      ),
      labels: progress_tooltip.Labels(
        progress: "Progreso:",
        completed: "completadas",
        in_progress: "en curso",
        pending: "pendientes",
      ),
    )

  let html = progress_tooltip.view(config) |> element.to_document_string

  string.contains(html, "3") |> should.be_true
  string.contains(html, "completadas") |> should.be_true
  string.contains(html, "1") |> should.be_true
  string.contains(html, "en curso") |> should.be_true
  string.contains(html, "pendientes") |> should.be_true
}

pub fn calculates_percentage_display_test() {
  let config =
    progress_tooltip.Config(
      data: ProgressBreakdown(
        completed: 3,
        in_progress: 1,
        pending: 1,
        percentage: 60,
      ),
      labels: progress_tooltip.Labels(
        progress: "Progreso:",
        completed: "completadas",
        in_progress: "en curso",
        pending: "pendientes",
      ),
    )

  let html = progress_tooltip.view(config) |> element.to_document_string

  string.contains(html, "Progreso:") |> should.be_true
  string.contains(html, "60%") |> should.be_true
}

pub fn handles_zero_tasks_test() {
  let config =
    progress_tooltip.Config(
      data: ProgressBreakdown(
        completed: 0,
        in_progress: 0,
        pending: 0,
        percentage: 0,
      ),
      labels: progress_tooltip.Labels(
        progress: "Progreso:",
        completed: "completadas",
        in_progress: "en curso",
        pending: "pendientes",
      ),
    )

  let html = progress_tooltip.view(config) |> element.to_document_string

  string.contains(html, "0") |> should.be_true
  string.contains(html, "completadas") |> should.be_true
}
