//// User domain type shared between client and server.
////
//// Represents an authenticated user with their organization membership
//// and role. This is the public user representation (no password hash).

import scrumbringer_domain/org_role.{type OrgRole}

/// An authenticated user in the system.
pub type User {
  User(
    id: Int,
    email: String,
    org_id: Int,
    org_role: OrgRole,
    created_at: String,
  )
}
