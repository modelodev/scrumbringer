//// Type-safe CSS class composition.
////
//// Provides compile-time validation for CSS class names used in views.
//// Prevents typos and ensures consistency across the codebase.

import gleam/list
import gleam/string

/// CSS class reference with compile-time safety.
pub opaque type CssClass {
  CssClass(name: String)
}

/// Converts a CSS class to its string representation.
pub fn to_string(css_class: CssClass) -> String {
  let CssClass(name) = css_class
  name
}

/// Combines multiple CSS classes into a space-separated string.
pub fn join(classes: List(CssClass)) -> String {
  classes
  |> list.map(to_string)
  |> string.join(" ")
}

/// Conditionally includes a class.
pub fn when(css_class: CssClass, condition: Bool) -> List(CssClass) {
  case condition {
    True -> [css_class]
    False -> []
  }
}

// =============================================================================
// Nav Item Classes
// =============================================================================

pub fn nav_item() -> CssClass {
  CssClass("nav-item")
}

pub fn active() -> CssClass {
  CssClass("active")
}

pub fn nav_item_icon() -> CssClass {
  CssClass("nav-item-icon")
}

// =============================================================================
// Empty State Classes
// =============================================================================

pub fn empty_state() -> CssClass {
  CssClass("empty-state")
}

pub fn empty_state_icon() -> CssClass {
  CssClass("empty-state-icon")
}

pub fn empty_state_text() -> CssClass {
  CssClass("empty-state-text")
}

// =============================================================================
// Admin Card Classes
// =============================================================================

pub fn admin_card() -> CssClass {
  CssClass("admin-card")
}

pub fn admin_card_header() -> CssClass {
  CssClass("admin-card-header")
}

// =============================================================================
// Info Callout Classes
// =============================================================================

pub fn info_callout() -> CssClass {
  CssClass("info-callout")
}

pub fn info_callout_icon() -> CssClass {
  CssClass("info-callout-icon")
}

pub fn info_callout_content() -> CssClass {
  CssClass("info-callout-content")
}

pub fn info_callout_title() -> CssClass {
  CssClass("info-callout-title")
}

pub fn info_callout_text() -> CssClass {
  CssClass("info-callout-text")
}

// =============================================================================
// Button Classes
// =============================================================================

pub fn btn_xs() -> CssClass {
  CssClass("btn-xs")
}

pub fn btn_active() -> CssClass {
  CssClass("btn-active")
}

pub fn btn_icon() -> CssClass {
  CssClass("btn-icon")
}

pub fn btn_loading() -> CssClass {
  CssClass("btn-loading")
}

// =============================================================================
// Task Card Classes
// =============================================================================

pub fn task_card() -> CssClass {
  CssClass("task-card")
}

pub fn highlight() -> CssClass {
  CssClass("highlight")
}

pub fn preview_left() -> CssClass {
  CssClass("preview-left")
}

pub fn decay_badge() -> CssClass {
  CssClass("decay-badge")
}

// =============================================================================
// Error Classes
// =============================================================================

pub fn error_banner() -> CssClass {
  CssClass("error-banner")
}

pub fn error_banner_icon() -> CssClass {
  CssClass("error-banner-icon")
}

pub fn error_banner_text() -> CssClass {
  CssClass("error-banner-text")
}
