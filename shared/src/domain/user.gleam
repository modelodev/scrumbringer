//// User domain type shared between client and server.
////
//// ## Mission
////
//// Represents an authenticated user with their organization membership
//// and role. This is the public user representation (no password hash).
////
//// ## Responsibilities
////
//// - User type definition
////
//// ## Non-responsibilities
////
//// - Authentication logic (see server/auth)
//// - Password handling (see server/password)
////
//// ## Relations
////
//// - **domain/org_role.gleam**: User has an OrgRole
//// - **client/client_state.gleam**: Model contains current User

import domain/org_role.{type OrgRole}

/// An authenticated user in the system.
///
/// ## Example
///
/// ```gleam
/// User(
///   id: 1,
///   email: "user@example.com",
///   org_id: 42,
///   org_role: Admin,
///   created_at: "2024-01-17T12:00:00Z",
/// )
/// ```
pub type User {
  User(
    id: Int,
    email: String,
    org_id: Int,
    org_role: OrgRole,
    created_at: String,
  )
}
