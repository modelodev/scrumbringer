//// Field update type for partial updates (PATCH operations).
////
//// Provides a type-safe way to represent optional field updates where:
//// - `Unchanged` means the field was not present in the request
//// - `Set(value)` means the field should be updated to the given value
////
//// This replaces the sentinel value pattern ("__unset__", -1) with
//// explicit types for better type safety and code clarity.

import gleam/option.{type Option}

/// Represents a field that may or may not be updated in a PATCH request.
pub type FieldUpdate(a) {
  /// Field was not included in the request - keep existing value
  Unchanged
  /// Field was included - update to new value
  Set(a)
}

// =============================================================================
// Constructors
// =============================================================================

/// Create an unchanged field update.
pub fn unchanged() -> FieldUpdate(a) {
  Unchanged
}

/// Create a field update with a new value.
pub fn set(value: a) -> FieldUpdate(a) {
  Set(value)
}

// =============================================================================
// Conversions
// =============================================================================

/// Convert a FieldUpdate to an Option.
/// Unchanged becomes None, Set(v) becomes Some(v).
pub fn to_option(field: FieldUpdate(a)) -> Option(a) {
  case field {
    Unchanged -> option.None
    Set(value) -> option.Some(value)
  }
}

/// Create a FieldUpdate from an Option.
/// None becomes Unchanged, Some(v) becomes Set(v).
pub fn from_option(opt: Option(a)) -> FieldUpdate(a) {
  case opt {
    option.None -> Unchanged
    option.Some(value) -> Set(value)
  }
}

/// Convert a sentinel value to FieldUpdate.
/// If value equals sentinel, returns Unchanged; otherwise Set(value).
pub fn from_sentinel(value: a, sentinel: a) -> FieldUpdate(a) {
  case value == sentinel {
    True -> Unchanged
    False -> Set(value)
  }
}

/// Convert FieldUpdate to a sentinel value.
/// Unchanged becomes the sentinel value; Set(v) becomes v.
pub fn to_sentinel(field: FieldUpdate(a), sentinel: a) -> a {
  case field {
    Unchanged -> sentinel
    Set(value) -> value
  }
}

// =============================================================================
// Predicates
// =============================================================================

/// Check if the field update is unchanged.
pub fn is_unchanged(field: FieldUpdate(a)) -> Bool {
  case field {
    Unchanged -> True
    Set(_) -> False
  }
}

/// Check if the field update has a new value.
pub fn is_set(field: FieldUpdate(a)) -> Bool {
  case field {
    Unchanged -> False
    Set(_) -> True
  }
}

// =============================================================================
// Transformations
// =============================================================================

/// Apply a function to the value if it's Set.
pub fn map(field: FieldUpdate(a), f: fn(a) -> b) -> FieldUpdate(b) {
  case field {
    Unchanged -> Unchanged
    Set(value) -> Set(f(value))
  }
}

/// Get the value or a default if unchanged.
pub fn unwrap(field: FieldUpdate(a), default: a) -> a {
  case field {
    Unchanged -> default
    Set(value) -> value
  }
}
