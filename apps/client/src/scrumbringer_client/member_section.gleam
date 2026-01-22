//// Member section navigation for the client UI.
////
//// Defines the available sections in the member view and provides
//// slug conversion utilities for URL routing.

/// Available member view sections.
///
/// ## Example
///
/// ```gleam
/// let section = MemberSection.Pool
/// to_slug(section)
/// // -> "pool"
/// ```
pub type MemberSection {
  Pool
  MyBar
  MySkills
  Fichas
}

/// Parses a URL slug into a MemberSection (defaults to Pool).
///
/// Story 4.4: my-bar and my-skills are deprecated - redirect to Pool.
/// Their functionality moves to the right panel of the 3-panel layout.
///
/// ## Example
///
/// ```gleam
/// from_slug("fichas")
/// // -> Fichas
///
/// from_slug("my-bar")  // deprecated
/// // -> Pool
/// ```
pub fn from_slug(slug: String) -> MemberSection {
  case slug {
    "fichas" -> Fichas
    "pool" -> Pool
    // Story 4.4: Deprecated routes redirect to Pool
    // "my-bar" and "my-skills" content now lives in right panel
    "my-bar" | "my-skills" -> Pool
    _ -> Pool
  }
}

/// Returns True if the slug is deprecated and should trigger a redirect.
pub fn is_deprecated_slug(slug: String) -> Bool {
  case slug {
    "my-bar" | "my-skills" -> True
    _ -> False
  }
}

/// Converts a MemberSection to its URL slug representation.
///
/// ## Example
///
/// ```gleam
/// to_slug(MySkills)
/// // -> "my-skills"
/// ```
pub fn to_slug(section: MemberSection) -> String {
  case section {
    Pool -> "pool"
    MyBar -> "my-bar"
    MySkills -> "my-skills"
    Fichas -> "fichas"
  }
}
