import lustre/element
import lustre/element/html.{div, text}
import scrumbringer_client/features/layout/three_panel_layout as layout
import support/render_assertions

fn assert_not_equal(actual: a, unexpected: a) {
  let assert False = actual == unexpected
}

// =============================================================================
// Builder tests
// =============================================================================

pub fn config_creates_empty_config_test() {
  let config = layout.config()
  // Config should exist and be usable
  let rendered = layout.render(config)
  rendered |> element.to_document_string |> assert_not_equal("")
}

pub fn with_left_panel_sets_content_test() {
  let content = div([], [text("Left")])
  let config =
    layout.config()
    |> layout.with_left_panel(content)

  let rendered = layout.render(config)
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Left")
}

pub fn with_center_panel_sets_content_test() {
  let content = div([], [text("Center")])
  let config =
    layout.config()
    |> layout.with_center_panel(content)

  let rendered = layout.render(config)
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Center")
}

pub fn with_right_panel_sets_content_test() {
  let content = div([], [text("Right")])
  let config =
    layout.config()
    |> layout.with_right_panel(content)

  let rendered = layout.render(config)
  let html = element.to_document_string(rendered)

  render_assertions.contains(html, "Right")
}

// =============================================================================
// Semantic HTML tests
// =============================================================================

pub fn render_includes_nav_element_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "<nav")
}

pub fn render_includes_main_element_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "<main")
}

pub fn render_includes_aside_element_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "<aside")
}

// =============================================================================
// data-testid tests (for E2E)
// =============================================================================

pub fn render_includes_left_panel_testid_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"left-panel\"")
}

pub fn render_includes_center_panel_testid_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"center-panel\"")
}

pub fn render_includes_right_panel_testid_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "data-testid=\"right-panel\"")
}

// =============================================================================
// ARIA tests
// =============================================================================

pub fn render_includes_main_content_id_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "id=\"main-content\"")
}

pub fn render_includes_aria_labels_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  // Should have aria-label on nav and aside
  render_assertions.contains(html, "aria-label=")
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

  render_assertions.contains(html, "Navegacion principal")
}

// =============================================================================
// CSS class tests
// =============================================================================

pub fn render_includes_layout_class_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "three-panel-layout")
}

pub fn render_includes_panel_classes_test() {
  let html =
    layout.view(element.none(), element.none(), element.none())
    |> element.to_document_string

  render_assertions.contains(html, "panel-left")
  render_assertions.contains(html, "panel-center")
  render_assertions.contains(html, "panel-right")
}
