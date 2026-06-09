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

pub type MemberSectionParseError {
  UnknownMemberSection(String)
}

/// Parses a URL slug into a MemberSection.
///
/// ## Example
///
/// ```gleam
/// parse_slug("fichas")
/// // -> Ok(Fichas)
///
/// parse_slug("my-bar")
/// // -> Ok(MyBar)
/// ```
pub fn parse_slug(
  slug: String,
) -> Result(MemberSection, MemberSectionParseError) {
  case slug {
    "" | "pool" -> Ok(Pool)
    "fichas" -> Ok(Fichas)
    "my-bar" -> Ok(MyBar)
    "my-skills" -> Ok(MySkills)
    other -> Error(UnknownMemberSection(other))
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
