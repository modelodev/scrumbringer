import gleam/int

import domain/org.{type OrgUser, OrgUser}
import domain/org_role

pub fn from_id(user_id: Int) -> OrgUser {
  OrgUser(
    id: user_id,
    email: "User #" <> int.to_string(user_id),
    org_role: org_role.Member,
    created_at: "",
  )
}
