import gleam/option.{Some}
import gleam/string
import lustre/element
import lustre/element/html.{button, text}

import scrumbringer_client/features/layout/work_surface

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn work_surface_header_renders_contract_test() {
  let html =
    work_surface.HeaderConfig(
      title: "Pool",
      purpose: "Choose work.",
      summary: [
        work_surface.summary_chip("Available", "4", work_surface.Available),
        work_surface.summary_chip("Blocked", "1", work_surface.Blocked),
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
