//// Organization role domain type shared between client and server.
////
//// Defines the permission levels within an organization.

/// A user's role within an organization.
pub type OrgRole {
  Admin
  Member
}

/// Converts an org role to its string representation.
pub fn to_string(role: OrgRole) -> String {
  case role {
    Admin -> "admin"
    Member -> "member"
  }
}

/// Parses a string into an org role.
pub fn parse(value: String) -> Result(OrgRole, Nil) {
  case value {
    "admin" -> Ok(Admin)
    "member" -> Ok(Member)
    _ -> Error(Nil)
  }
}
