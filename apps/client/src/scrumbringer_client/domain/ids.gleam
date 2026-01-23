//// Opaque ID Types for Scrumbringer Client
////
//// ## Mission
////
//// Provide type-safe opaque ID wrappers to prevent accidental mixing of
//// different ID types. Using opaque types ensures compile-time safety.
////
//// ## Responsibilities
////
//// - Define opaque types for various IDs (ToastId, etc.)
//// - Provide constructors and accessors
//// - Provide equality functions
////
//// ## Non-responsibilities
////
//// - Business logic involving IDs
//// - ID generation strategies (handled by callers)
////
//// ## Design Principles
////
//// - **Opaque types**: Internal representation hidden from callers
//// - **Smart constructors**: Validate inputs where needed
//// - **Minimal API**: Only expose what's necessary

// =============================================================================
// ToastId - Opaque type for toast notification IDs
// =============================================================================

/// ID for toast notifications - opaque to prevent misuse.
///
/// Using an opaque type prevents accidentally passing an Int where a ToastId
/// is expected, catching bugs at compile time.
pub opaque type ToastId {
  ToastId(Int)
}

/// Create a new ToastId from an integer value.
///
/// ## Example
///
/// ```gleam
/// let id = new_toast_id(1)
/// ```
pub fn new_toast_id(value: Int) -> ToastId {
  ToastId(value)
}

/// Extract the underlying integer value from a ToastId.
///
/// Only use when necessary (e.g., for serialization or logging).
///
/// ## Example
///
/// ```gleam
/// let id = new_toast_id(42)
/// toast_id_to_int(id)  // 42
/// ```
pub fn toast_id_to_int(id: ToastId) -> Int {
  let ToastId(value) = id
  value
}

/// Compare two ToastIds for equality.
///
/// ## Example
///
/// ```gleam
/// let id1 = new_toast_id(1)
/// let id2 = new_toast_id(1)
/// toast_id_eq(id1, id2)  // True
/// ```
pub fn toast_id_eq(a: ToastId, b: ToastId) -> Bool {
  toast_id_to_int(a) == toast_id_to_int(b)
}
