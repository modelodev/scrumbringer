//// Capability domain types for ScrumBringer.
////
//// Defines capability structures used for skill-based task filtering.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/capability.{type Capability}
////
//// let cap = Capability(id: 1, name: "Backend Development")
//// ```

// =============================================================================
// Types
// =============================================================================

/// A capability that can be assigned to task types.
///
/// ## Example
///
/// ```gleam
/// Capability(id: 1, name: "Frontend Development")
/// ```
pub type Capability {
  Capability(id: Int, name: String)
}
