//// Tests for progress tooltip (AC18).

import support/render_assertions

import scrumbringer_client/ui/tooltips/progress_tooltip
import scrumbringer_client/ui/tooltips/types.{ProgressBreakdown}

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

  let html = progress_tooltip.view(config) |> render_assertions.html

  render_assertions.contains(html, "3")
  render_assertions.contains(html, "cerradas")
  render_assertions.contains(html, "1")
  render_assertions.contains(html, "en curso")
  render_assertions.contains(html, "pendientes")
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

  let html = progress_tooltip.view(config) |> render_assertions.html

  render_assertions.contains(html, "Progreso:")
  render_assertions.contains(html, "60%")
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

  let html = progress_tooltip.view(config) |> render_assertions.html

  render_assertions.contains(html, "0")
  render_assertions.contains(html, "cerradas")
}
