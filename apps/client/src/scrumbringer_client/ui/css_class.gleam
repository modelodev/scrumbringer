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

/// Provides nav item.
///
/// Example:
///   nav_item(...)
pub fn nav_item() -> CssClass {
  CssClass("nav-item")
}

/// Provides active.
///
/// Example:
///   active(...)
pub fn active() -> CssClass {
  CssClass("active")
}

/// Provides nav item icon.
///
/// Example:
///   nav_item_icon(...)
pub fn nav_item_icon() -> CssClass {
  CssClass("nav-item-icon")
}

// =============================================================================
// Empty State Classes
// =============================================================================

/// Provides empty state.
///
/// Example:
///   empty_state(...)
pub fn empty_state() -> CssClass {
  CssClass("empty-state")
}

/// Provides empty state icon.
///
/// Example:
///   empty_state_icon(...)
pub fn empty_state_icon() -> CssClass {
  CssClass("empty-state-icon")
}

/// Provides empty state text.
///
/// Example:
///   empty_state_text(...)
pub fn empty_state_text() -> CssClass {
  CssClass("empty-state-text")
}

// =============================================================================
// Admin Card Classes
// =============================================================================

/// Provides admin card.
///
/// Example:
///   admin_card(...)
pub fn admin_card() -> CssClass {
  CssClass("admin-card")
}

/// Provides admin card header.
///
/// Example:
///   admin_card_header(...)
pub fn admin_card_header() -> CssClass {
  CssClass("admin-card-header")
}

// =============================================================================
// Info Callout Classes
// =============================================================================

/// Provides info callout.
///
/// Example:
///   info_callout(...)
pub fn info_callout() -> CssClass {
  CssClass("info-callout")
}

/// Provides info callout icon.
///
/// Example:
///   info_callout_icon(...)
pub fn info_callout_icon() -> CssClass {
  CssClass("info-callout-icon")
}

/// Provides info callout content.
///
/// Example:
///   info_callout_content(...)
pub fn info_callout_content() -> CssClass {
  CssClass("info-callout-content")
}

/// Provides info callout title.
///
/// Example:
///   info_callout_title(...)
pub fn info_callout_title() -> CssClass {
  CssClass("info-callout-title")
}

/// Provides info callout text.
///
/// Example:
///   info_callout_text(...)
pub fn info_callout_text() -> CssClass {
  CssClass("info-callout-text")
}

// =============================================================================
// Button Classes
// =============================================================================

/// Provides btn xs.
///
/// Example:
///   btn_xs(...)
pub fn btn_xs() -> CssClass {
  CssClass("btn-xs")
}

/// Provides btn active.
///
/// Example:
///   btn_active(...)
pub fn btn_active() -> CssClass {
  CssClass("btn-active")
}

/// Provides btn icon.
///
/// Example:
///   btn_icon(...)
pub fn btn_icon() -> CssClass {
  CssClass("btn-icon")
}

/// Provides btn loading.
///
/// Example:
///   btn_loading(...)
pub fn btn_loading() -> CssClass {
  CssClass("btn-loading")
}

// =============================================================================
// Task Card Classes
// =============================================================================

/// Provides task card.
///
/// Example:
///   task_card(...)
pub fn task_card() -> CssClass {
  CssClass("task-card")
}

/// Provides highlight.
///
/// Example:
///   highlight(...)
pub fn highlight() -> CssClass {
  CssClass("highlight")
}

/// Provides preview left.
///
/// Example:
///   preview_left(...)
pub fn preview_left() -> CssClass {
  CssClass("preview-left")
}

/// Provides decay badge.
///
/// Example:
///   decay_badge(...)
pub fn decay_badge() -> CssClass {
  CssClass("decay-badge")
}

// =============================================================================
// Error Classes
// =============================================================================

/// Provides error banner.
///
/// Example:
///   error_banner(...)
pub fn error_banner() -> CssClass {
  CssClass("error-banner")
}

/// Provides error banner icon.
///
/// Example:
///   error_banner_icon(...)
pub fn error_banner_icon() -> CssClass {
  CssClass("error-banner-icon")
}

/// Provides error banner text.
///
/// Example:
///   error_banner_text(...)
pub fn error_banner_text() -> CssClass {
  CssClass("error-banner-text")
}
