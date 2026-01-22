//// ThreePanelLayout - Composable 3-panel layout component
////
//// Mission: Provide a type-safe, accessible layout structure with semantic
//// HTML landmarks (nav, main, aside) and proper ARIA attributes.
////
//// Responsibilities:
//// - Render 3-panel desktop layout with nav, main, aside
//// - Apply correct ARIA landmarks for accessibility
//// - Include data-testid attributes for E2E testing
//// - Provide slot-based composition for panel contents
////
//// Non-responsibilities:
//// - Panel content rendering (passed as children)
//// - Responsive breakpoints (handled by CSS + parent components)
//// - Navigation logic (handled by parent)

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html.{aside, div, main, nav}

// =============================================================================
// Types
// =============================================================================

/// Configuration for the three panel layout
pub type LayoutConfig(msg) {
  LayoutConfig(
    left_panel: Element(msg),
    center_panel: Element(msg),
    right_panel: Element(msg),
    extra_attrs: List(Attribute(msg)),
  )
}

// =============================================================================
// Constructors
// =============================================================================

/// Creates a default layout config with empty panels
pub fn config() -> LayoutConfig(msg) {
  LayoutConfig(
    left_panel: element.none(),
    center_panel: element.none(),
    right_panel: element.none(),
    extra_attrs: [],
  )
}

// =============================================================================
// Builders
// =============================================================================

/// Sets the left panel content (navigation)
pub fn with_left_panel(
  config: LayoutConfig(msg),
  content: Element(msg),
) -> LayoutConfig(msg) {
  LayoutConfig(..config, left_panel: content)
}

/// Sets the center panel content (main content area)
pub fn with_center_panel(
  config: LayoutConfig(msg),
  content: Element(msg),
) -> LayoutConfig(msg) {
  LayoutConfig(..config, center_panel: content)
}

/// Sets the right panel content (activity/profile panel)
pub fn with_right_panel(
  config: LayoutConfig(msg),
  content: Element(msg),
) -> LayoutConfig(msg) {
  LayoutConfig(..config, right_panel: content)
}

/// Adds extra attributes to the layout container
pub fn with_attrs(
  config: LayoutConfig(msg),
  attrs: List(Attribute(msg)),
) -> LayoutConfig(msg) {
  LayoutConfig(..config, extra_attrs: attrs)
}

// =============================================================================
// Rendering
// =============================================================================

/// Renders the three-panel layout with semantic HTML and ARIA landmarks
///
/// Structure:
/// ```
/// <div class="three-panel-layout" ...extra_attrs>
///   <nav data-testid="left-panel" aria-label="...">
///     {left_panel}
///   </nav>
///   <main data-testid="center-panel" id="main-content">
///     {center_panel}
///   </main>
///   <aside data-testid="right-panel" aria-label="...">
///     {right_panel}
///   </aside>
/// </div>
/// ```
pub fn render(config: LayoutConfig(msg)) -> Element(msg) {
  render_with_labels(config, "Main navigation", "My activity")
}

/// Renders with custom ARIA labels (for i18n support)
pub fn render_with_labels(
  config: LayoutConfig(msg),
  nav_label: String,
  aside_label: String,
) -> Element(msg) {
  let base_attrs = [attribute.class("three-panel-layout")]

  div(list.flatten([base_attrs, config.extra_attrs]), [
    // Left panel: Navigation
    nav(
      [
        attribute.attribute("data-testid", "left-panel"),
        attribute.attribute("aria-label", nav_label),
        attribute.class("panel-left"),
      ],
      [config.left_panel],
    ),
    // Center panel: Main content
    main(
      [
        attribute.attribute("data-testid", "center-panel"),
        attribute.id("main-content"),
        attribute.attribute("tabindex", "-1"),
        attribute.class("panel-center"),
      ],
      [config.center_panel],
    ),
    // Right panel: Activity/Profile
    aside(
      [
        attribute.attribute("data-testid", "right-panel"),
        attribute.attribute("aria-label", aside_label),
        attribute.class("panel-right"),
      ],
      [config.right_panel],
    ),
  ])
}

// =============================================================================
// Alternative: Simple function-based API
// =============================================================================

/// Simple function to render a three-panel layout
///
/// For cases where the builder pattern is overkill
pub fn view(
  left: Element(msg),
  center: Element(msg),
  right: Element(msg),
) -> Element(msg) {
  config()
  |> with_left_panel(left)
  |> with_center_panel(center)
  |> with_right_panel(right)
  |> render()
}

/// Renders with i18n-aware labels
pub fn view_i18n(
  left: Element(msg),
  center: Element(msg),
  right: Element(msg),
  nav_label: String,
  aside_label: String,
) -> Element(msg) {
  config()
  |> with_left_panel(left)
  |> with_center_panel(center)
  |> with_right_panel(right)
  |> render_with_labels(nav_label, aside_label)
}

// =============================================================================
// Imports (grouped at end to keep API visible first)
// =============================================================================

import gleam/list
