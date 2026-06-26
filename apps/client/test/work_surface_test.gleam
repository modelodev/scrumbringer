import gleam/option.{Some}
import gleam/string
import lustre/element
import lustre/element/html.{button, div, text}

import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/ui/tone

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

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
    |> element.to_document_string

  assert_contains(html, "work-surface-header pool-header")
  assert_contains(html, "data-testid=\"surface-header\"")
  assert_contains(html, ">Pool<")
  assert_contains(html, ">Choose work.<")
  assert_contains(html, "work-surface-summary")
  assert_contains(html, "work-surface-chip available")
  assert_contains(html, "work-surface-chip blocked")
  assert_contains(html, ">4<")
  assert_contains(html, ">Available<")
  assert_contains(html, "work-surface-actions")
  assert_contains(html, ">Create<")
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
    |> element.to_document_string

  assert_contains(html, "work-surface pool-surface")
  assert_contains(html, "data-testid=\"pool-surface\"")
  assert_contains(html, "work-surface-filters")
  assert_contains(html, "work-surface-state")
  assert_contains(html, "work-surface-content")
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
    |> element.to_document_string

  assert_contains(html, "work-surface-header")
  assert_not_contains(html, "work-surface-filters")
  assert_not_contains(html, "work-surface-state")
  assert_not_contains(html, "work-surface-content")
}
