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
}

/// Parses a URL slug into a MemberSection (defaults to Pool).
///
/// ## Example
///
/// ```gleam
/// from_slug("my-bar")
/// // -> MyBar
/// ```
pub fn from_slug(slug: String) -> MemberSection {
  case slug {
    "my-bar" -> MyBar
    "my-skills" -> MySkills
    "pool" -> Pool
    _ -> Pool
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
  }
}
