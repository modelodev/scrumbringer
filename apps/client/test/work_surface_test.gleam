import gleam/option.{Some}
import gleam/string
import lustre/element/html.{button, div, text}
import support/render_assertions

import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/tone

fn appears_before(html: String, first: String, second: String) -> Bool {
  case string.split_once(html, first) {
    Ok(#(_, after_first)) -> string.contains(after_first, second)
    Error(_) -> False
  }
}

pub fn work_surface_header_renders_contract_test() {
  let html =
    work_surface.HeaderConfig(
      title: "Pool",
      purpose: "Choose work.",
      summary: [
        work_surface.summary_chip("Available", "4", tone.Available),
        work_surface.summary_chip("Blocked", "1", tone.Blocked),
      ],
      actions: [button([], [text("Create")])],
      extra_class: Some("pool-header"),
      testid: Some("surface-header"),
    )
    |> work_surface.header
    |> render_assertions.html

  render_assertions.contains(html, "work-surface-header pool-header")
  render_assertions.contains(html, "data-testid=\"surface-header\"")
  render_assertions.contains(html, ">Pool<")
  render_assertions.contains(html, ">Choose work.<")
  render_assertions.contains(html, "work-surface-summary")
  render_assertions.contains(html, "work-surface-chip available")
  render_assertions.contains(html, "work-surface-chip blocked")
  render_assertions.contains(html, ">4<")
  render_assertions.contains(html, ">Available<")
  render_assertions.contains(html, "work-surface-actions")
  render_assertions.contains(html, ">Create<")
}

pub fn work_surface_header_renders_task_summary_chip_test() {
  let html =
    work_surface.HeaderConfig(
      title: "Kanban",
      purpose: "Track work.",
      summary: [
        work_surface.task_summary_chip(locale.En, task_metric.Available, 3),
        work_surface.task_summary_chip(locale.En, task_metric.Blocked, 1),
      ],
      actions: [],
      extra_class: Some("kanban-header"),
      testid: Some("surface-header"),
    )
    |> work_surface.header
    |> render_assertions.html

  render_assertions.contains(html, "task-metric-chip is-compact available")
  render_assertions.contains(html, "task-metric-chip is-compact blocked")
  render_assertions.contains(html, "data-testid=\"work-surface-chip\"")
  render_assertions.contains(html, "title=\"Available: 3\"")
  render_assertions.contains(html, "aria-label=\"Blocked: 1\"")
  render_assertions.contains(html, "task-metric-chip-icon")
  render_assertions.not_contains(html, "task-metric-chip-label")
  render_assertions.not_contains(html, ">Available<")
  render_assertions.not_contains(html, ">Blocked<")
}

pub fn work_surface_surface_renders_optional_slots_in_order_test() {
  let header =
    work_surface.HeaderConfig(
      title: "Pool",
      purpose: "Choose work.",
      summary: [],
      actions: [],
      extra_class: Some("pool-header"),
      testid: Some("surface-header"),
    )
    |> work_surface.header

  let html =
    work_surface.new_surface(header)
    |> work_surface.with_filters(div([], [text("Filters")]))
    |> work_surface.with_state(div([], [text("Loading")]))
    |> work_surface.with_content(div([], [text("Tasks")]))
    |> work_surface.surface_with_class("pool-surface")
    |> work_surface.surface_with_testid("pool-surface")
    |> work_surface.surface
    |> render_assertions.html

  render_assertions.contains(html, "work-surface pool-surface")
  render_assertions.contains(html, "data-testid=\"pool-surface\"")
  render_assertions.contains(html, "work-surface-filters")
  render_assertions.contains(html, "work-surface-state")
  render_assertions.contains(html, "work-surface-content")
  let assert True = appears_before(html, ">Filters<", ">Loading<")
  let assert True = appears_before(html, ">Loading<", ">Tasks<")
}

pub fn work_surface_surface_omits_missing_slots_test() {
  let header =
    work_surface.HeaderConfig(
      title: "Pool",
      purpose: "Choose work.",
      summary: [],
      actions: [],
      extra_class: Some("pool-header"),
      testid: Some("surface-header"),
    )
    |> work_surface.header

  let html =
    work_surface.new_surface(header)
    |> work_surface.surface
    |> render_assertions.html

  render_assertions.contains(html, "work-surface-header")
  render_assertions.not_contains(html, "work-surface-filters")
  render_assertions.not_contains(html, "work-surface-state")
  render_assertions.not_contains(html, "work-surface-content")
}
