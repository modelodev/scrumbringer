import gleam/string
import gleeunit/should
import lustre/element
import lustre/element/html.{div, text}
import scrumbringer_client/features/layout/three_panel_layout as layout

// =============================================================================
// Builder tests
// =============================================================================

pub fn config_creates_empty_config_test() {
  let config = layout.config()
  // Config should exist and be usable
  let rendered = layout.render(config)
  rendered |> element.to_document_string |> should.not_equal("")
}

pub fn with_left_panel_sets_content_test() {
  let content = div([], [text("Left")])
  let config =
    layout.config()
    |> layout.with_left_panel(content)

  let rendered = layout.render(config)
  let html = element.to_document_string(rendered)

  string.contains(html, "Left") |> should.be_true
}

pub fn with_center_panel_sets_content_test() {
  let content = div([], [text("Center")])
  let config =
    layout.config()
    |> layout.with_center_panel(content)

  let rendered = layout.render(config)
  let html = element.to_document_string(rendered)

  string.contains(html, "Center") |> should.be_true
}

pub fn with_right_panel_sets_content_test() {
  let content = div([], [text("Right")])
  let config =
    layout.config()
    |> layout.with_right_panel(content)

  let rendered = layout.render(config)
  let html = element.to_document_string(rendered)

  string.contains(html, "Right") |> should.be_true
}

// =============================================================================
// Semantic HTML tests
// =============================================================================

pub fn render_includes_nav_element_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "<nav") |> should.be_true
}

pub fn render_includes_main_element_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "<main") |> should.be_true
}

pub fn render_includes_aside_element_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "<aside") |> should.be_true
}

// =============================================================================
// data-testid tests (for E2E)
// =============================================================================

pub fn render_includes_left_panel_testid_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "data-testid=\"left-panel\"") |> should.be_true
}

pub fn render_includes_center_panel_testid_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "data-testid=\"center-panel\"") |> should.be_true
}

pub fn render_includes_right_panel_testid_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "data-testid=\"right-panel\"") |> should.be_true
}

// =============================================================================
// ARIA tests
// =============================================================================

pub fn render_includes_main_content_id_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "id=\"main-content\"") |> should.be_true
}

pub fn render_includes_aria_labels_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  // Should have aria-label on nav and aside
  string.contains(html, "aria-label=") |> should.be_true
}

pub fn render_with_labels_uses_custom_labels_test() {
  let html =
    layout.view_i18n(
      element.none(),
      element.none(),
      element.none(),
      "Navegacion principal",
      "Mi actividad",
    )
    |> element.to_document_string

  string.contains(html, "Navegacion principal") |> should.be_true
}

// =============================================================================
// CSS class tests
// =============================================================================

pub fn render_includes_layout_class_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "three-panel-layout") |> should.be_true
}

pub fn render_includes_panel_classes_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  string.contains(html, "panel-left") |> should.be_true
  string.contains(html, "panel-center") |> should.be_true
  string.contains(html, "panel-right") |> should.be_true
}
