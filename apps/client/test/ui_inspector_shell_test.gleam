import gleam/string

import lustre/element
import lustre/element/html.{span, text}

import scrumbringer_client/ui/inspector_shell

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

pub fn detail_renders_shared_header_body_and_overlays_test() {
  let html =
    inspector_shell.detail(
      inspector_shell.Config(
        root_class: "example-root",
        panel_class: "example-panel",
        title_id: "example-title",
        testid: "example-inspector",
      ),
      "example-header",
      "example-body",
      span([], [text("Header")]),
      span([], [text("Tabs")]),
      span([], [text("Body")]),
      [span([], [text("Overlay")])],
    )
    |> element.to_document_string

  assert_contains(html, "example-root inspector-shell")
  assert_contains(html, "example-panel inspector-panel")
  assert_contains(html, "data-testid=\"example-inspector\"")
  assert_contains(html, "aria-labelledby=\"example-title\"")
  assert_contains(html, "example-header detail-header-block")
  assert_contains(html, "example-body")
  assert_contains(html, "Header")
  assert_contains(html, "Tabs")
  assert_contains(html, "Body")
  assert_contains(html, "Overlay")
}
