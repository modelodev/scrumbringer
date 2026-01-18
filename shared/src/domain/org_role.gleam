//// Organization role domain type shared between client and server.
////
//// ## Mission
////
//// Defines the permission levels within an organization using a type-safe ADT.
////
//// ## Responsibilities
////
//// - OrgRole type definition (Admin, Member)
//// - String serialization/deserialization
////
//// ## Non-responsibilities
////
//// - Permission logic (see client/permissions.gleam)
//// - Role assignment (see server/auth)
////
//// ## Relations
////
//// - **domain/user.gleam**: User has an OrgRole
//// - **client/permissions.gleam**: Uses OrgRole for permission checks

/// A user's role within an organization.
pub type OrgRole {
  Admin
  Member
}

/// Converts an org role to its string representation.
///
/// ## Example
///
/// ```gleam
/// to_string(Admin)  // "admin"
/// to_string(Member) // "member"
/// ```
pub fn to_string(role: OrgRole) -> String {
  case role {
    Admin -> "admin"
    Member -> "member"
  }
}

/// Parses a string into an org role.
///
/// ## Example
///
/// ```gleam
/// parse("admin")   // Ok(Admin)
/// parse("member")  // Ok(Member)
/// parse("unknown") // Error(Nil)
/// ```
pub fn parse(value: String) -> Result(OrgRole, Nil) {
  case value {
    "admin" -> Ok(Admin)
    "member" -> Ok(Member)
    _ -> Error(Nil)
  }
}
