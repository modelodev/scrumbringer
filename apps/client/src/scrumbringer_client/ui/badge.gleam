//// Badge component with smart constructors for type safety.
////
//// ## Mission
////
//// Provide a type-safe badge component with validation.
//// Uses opaque types and smart constructors to ensure badges
//// cannot be created with invalid data (e.g., empty text).
////
//// ## Design Principles
////
//// - **Opaque Badge type**: Internal structure hidden
//// - **Smart constructors**: Validate inputs at creation time
//// - **ADT for variants**: Compile-time exhaustive handling
////
//// ## Responsibilities
////
//// - Define badge variants (Primary, Success, Warning, Danger, Neutral)
//// - Validate badge text is not empty
//// - Render badges with consistent styling
////
//// ## Relations
////
//// - **ui/toast.gleam**: May use badges for status
//// - **features/*/view.gleam**: Use for status indicators

import gleam/bool
import gleam/string

import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html.{span, text}

// =============================================================================
// Types
// =============================================================================

/// Badge variant - determines visual styling.
///
/// Using an ADT ensures all variants are handled in pattern matching.
/// Note: "Danger" instead of "Error" to avoid conflict with Result.Error
pub type BadgeVariant {
  Primary
  Success
  Warning
  Danger
  Neutral
}

/// Badge - opaque type that can only be created via constructors.
///
/// This ensures badges always have valid (non-empty) text.
pub opaque type Badge {
  Badge(text: String, variant: BadgeVariant)
}

// =============================================================================
// Smart Constructors
// =============================================================================

/// Create a new badge with validation.
///
/// Returns Error if text is empty.
///
/// ## Example
///
/// ```gleam
/// case badge.new("Active", badge.Success) {
///   Ok(b) -> badge.view(b)
///   Error(msg) -> html.text(msg)
/// }
/// ```
pub fn new(text_value: String, variant: BadgeVariant) -> Result(Badge, String) {
  use <- bool.guard(
    string.is_empty(string.trim(text_value)),
    Error("Badge text cannot be empty"),
  )
  Ok(Badge(text: text_value, variant:))
}

/// Create a badge that truncates text if too long.
///
/// Panics if original text is empty (use `new` for validation).
///
/// ## Example
///
/// ```gleam
/// let badge = badge.new_truncated("Very Long Status Name", badge.Neutral, 10)
/// // Shows "Very Long…"
/// ```
pub fn new_truncated(
  text_value: String,
  variant: BadgeVariant,
  max_len: Int,
) -> Badge {
  let trimmed = string.trim(text_value)
  let truncated = case string.length(trimmed) > max_len {
    True -> string.slice(trimmed, 0, max_len) <> "…"
    False -> trimmed
  }
  // If original text was empty, truncated will be empty - use let assert
  let assert Ok(badge) = new(truncated, variant)
  badge
}

/// Create a badge without validation (for internal use when text is known valid).
///
/// ## Safety
///
/// Only use when you're certain the text is non-empty.
pub fn new_unchecked(text_value: String, variant: BadgeVariant) -> Badge {
  Badge(text: text_value, variant:)
}

// =============================================================================
// Accessors
// =============================================================================

/// Get the badge text.
pub fn get_text(badge: Badge) -> String {
  let Badge(text: t, ..) = badge
  t
}

/// Get the badge variant.
pub fn get_variant(badge: Badge) -> BadgeVariant {
  let Badge(variant: v, ..) = badge
  v
}

// =============================================================================
// View Functions
// =============================================================================

/// Render a badge element.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(b) = badge.new("Done", badge.Success)
/// badge.view(b)
/// ```
pub fn view(badge: Badge) -> Element(msg) {
  let Badge(text: badge_text, variant:) = badge
  span([class(variant_to_class(variant))], [text(badge_text)])
}

/// Render a badge with additional CSS class.
pub fn view_with_class(badge: Badge, extra_class: String) -> Element(msg) {
  let Badge(text: badge_text, variant:) = badge
  span([class(variant_to_class(variant) <> " " <> extra_class)], [
    text(badge_text),
  ])
}

/// Render a badge inline (suitable for use within text).
pub fn view_inline(badge: Badge) -> Element(msg) {
  let Badge(text: badge_text, variant:) = badge
  span([class(variant_to_class(variant) <> " badge-inline")], [text(badge_text)])
}

// =============================================================================
// Helpers
// =============================================================================

/// Convert variant to CSS class.
fn variant_to_class(variant: BadgeVariant) -> String {
  case variant {
    Primary -> "badge badge-primary"
    Success -> "badge badge-success"
    Warning -> "badge badge-warning"
    Danger -> "badge badge-danger"
    Neutral -> "badge badge-neutral"
  }
}

/// Convert variant to text label (for debugging/logging).
pub fn variant_label(variant: BadgeVariant) -> String {
  case variant {
    Primary -> "primary"
    Success -> "success"
    Warning -> "warning"
    Danger -> "danger"
    Neutral -> "neutral"
  }
}

// =============================================================================
// Convenience Functions
// =============================================================================

/// Create and render a badge in one step.
///
/// Returns empty element if text is invalid.
///
/// ## Example
///
/// ```gleam
/// badge.quick("Active", badge.Success)
/// ```
pub fn quick(text_value: String, variant: BadgeVariant) -> Element(msg) {
  case new(text_value, variant) {
    Ok(b) -> view(b)
    Error(_) -> element.none()
  }
}

/// Create a status badge with predefined variants.
pub fn status(status_text: String) -> Element(msg) {
  let variant = case string.lowercase(status_text) {
    "done" | "completed" | "completada" | "terminada" -> Success
    "active" | "activo" | "activa" | "in progress" | "en progreso" -> Primary
    "pending" | "pendiente" | "waiting" | "esperando" -> Warning
    "error" | "failed" | "fallido" | "fallida" -> Danger
    _ -> Neutral
  }
  quick(status_text, variant)
}
