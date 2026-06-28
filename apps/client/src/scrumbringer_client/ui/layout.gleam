//// Shared layout components for page structure.
////
//// ## Mission
////
//// Provides reusable layout primitives for consistent page structure
//// across the application.
////
//// ## Responsibilities
////
//// - Page wrapper with consistent styling
//// - Section containers for content grouping
////
//// ## Non-responsibilities
////
//// - Feature-specific layouts (admin topbar, member nav)
//// - Content rendering (see features/*/view.gleam)
////
//// ## Relations
////
//// - **features/*/view.gleam**: Feature views use these layout helpers

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

/// Renders an empty placeholder div.
///
/// Useful for conditional rendering where an empty element is needed.
pub fn empty() -> Element(msg) {
  element.none()
}

/// Renders a section container with optional title.
///
/// ## Parameters
///
/// - `class`: CSS class for the section
/// - `children`: Child elements to render
pub fn section(class: String, children: List(Element(msg))) -> Element(msg) {
  div([attribute.class(class)], children)
}
