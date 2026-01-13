import scrumbringer_domain/org_role.{type OrgRole}

pub type User {
  User(
    id: Int,
    email: String,
    org_id: Int,
    org_role: OrgRole,
    created_at: String,
  )
}
