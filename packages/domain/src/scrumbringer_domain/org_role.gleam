pub type OrgRole {
  Admin
  Member
}

pub fn to_string(role: OrgRole) -> String {
  case role {
    Admin -> "admin"
    Member -> "member"
  }
}

pub fn parse(value: String) -> Result(OrgRole, Nil) {
  case value {
    "admin" -> Ok(Admin)
    "member" -> Ok(Member)
    _ -> Error(Nil)
  }
}
