import support/render_assertions

import lustre/element
import lustre/element/html.{span, text}

import scrumbringer_client/ui/inspector_shell

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

  render_assertions.contains(html, "example-root inspector-shell")
  render_assertions.contains(html, "example-panel inspector-panel")
  render_assertions.contains(html, "data-testid=\"example-inspector\"")
  render_assertions.contains(html, "aria-labelledby=\"example-title\"")
  render_assertions.contains(html, "example-header detail-header-block")
  render_assertions.contains(html, "example-body")
  render_assertions.contains(html, "Header")
  render_assertions.contains(html, "Tabs")
  render_assertions.contains(html, "Body")
  render_assertions.contains(html, "Overlay")
}
