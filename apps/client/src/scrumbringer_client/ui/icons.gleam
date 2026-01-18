//// Icon Components for Scrumbringer client.
////
//// ## Mission
////
//// Provide reusable icon rendering utilities for heroicons and task type icons.
////
//// ## Responsibilities
////
//// - Render heroicon outline SVG icons
//// - Render task type icons with theme awareness
////
//// ## Non-responsibilities
////
//// - Icon selection logic (handled by callers)
//// - Icon picker UI (see features/admin/view.gleam)
////
//// ## Relations
////
//// - **features/admin/view.gleam**: Uses for task type icons
//// - **features/my_bar/view.gleam**: Uses for task type icons
//// - **features/pool/view.gleam**: Uses for task type icons

import gleam/int
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{img}

import scrumbringer_client/client_state.{type Msg}
import scrumbringer_client/theme.{type Theme}

// =============================================================================
// Heroicon Utilities
// =============================================================================

/// Build the URL for a heroicon outline SVG.
pub fn heroicon_outline_url(name: String) -> String {
  "https://cdn.jsdelivr.net/npm/heroicons@2.2.0/24/outline/" <> name <> ".svg"
}

/// Render a heroicon outline as an inline img element.
pub fn view_heroicon_inline(
  name: String,
  size: Int,
  theme: Theme,
) -> Element(Msg) {
  let filter = case theme {
    theme.Dark -> "invert(1)"
    theme.Default -> ""
  }

  img([
    attribute.src(heroicon_outline_url(name)),
    attribute.alt(name),
    attribute.attribute("width", int.to_string(size)),
    attribute.attribute("height", int.to_string(size)),
    attribute.attribute(
      "style",
      "vertical-align:middle; filter:" <> filter <> ";",
    ),
  ])
}

// =============================================================================
// Task Type Icon Utilities
// =============================================================================

/// Render a task type icon inline with theme awareness.
///
/// Task type icons are stored as heroicon names in the database.
pub fn view_task_type_icon_inline(
  icon_name: String,
  size: Int,
  theme: Theme,
) -> Element(Msg) {
  case string.is_empty(icon_name) {
    True -> element.none()
    False -> view_heroicon_inline(icon_name, size, theme)
  }
}
