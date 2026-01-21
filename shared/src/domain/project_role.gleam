//// Project role domain type shared between client and server.
////
//// ## Mission
////
//// Defines the permission levels within a project using a type-safe ADT.
////
//// ## Responsibilities
////
//// - ProjectRole type definition (Manager, Member)
//// - String serialization/deserialization
//// - JSON encoding
////
//// ## Non-responsibilities
////
//// - Permission logic (see client/permissions.gleam)
//// - Role assignment (see server/projects.gleam)
////
//// ## Relations
////
//// - **domain/project.gleam**: ProjectMember has a ProjectRole
//// - **client/permissions.gleam**: Uses ProjectRole for permission checks

import gleam/json

/// A user's role within a project.
pub type ProjectRole {
  Manager
  Member
}

/// Converts a project role to its string representation.
///
/// ## Example
///
/// ```gleam
/// to_string(Manager) // "manager"
/// to_string(Member)  // "member"
/// ```
pub fn to_string(role: ProjectRole) -> String {
  case role {
    Manager -> "manager"
    Member -> "member"
  }
}

/// Parses a string into a project role.
///
/// ## Example
///
/// ```gleam
/// parse("manager") // Ok(Manager)
/// parse("member")  // Ok(Member)
/// parse("admin")   // Error(Nil)
/// ```
pub fn parse(value: String) -> Result(ProjectRole, Nil) {
  case value {
    "manager" -> Ok(Manager)
    "member" -> Ok(Member)
    _ -> Error(Nil)
  }
}

/// Converts a project role to JSON.
///
/// ## Example
///
/// ```gleam
/// to_json(Manager) // json.string("manager")
/// ```
pub fn to_json(role: ProjectRole) -> json.Json {
  json.string(to_string(role))
}
