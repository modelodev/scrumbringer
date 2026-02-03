//// In-memory state types for the application store.
////
//// Defines the data structures used by the in-memory store during
//// development and testing. Production uses the PostgreSQL database.

import domain/org_role.{type OrgRole}
import domain/project_role.{type ProjectRole}
import gleam/dict
import gleam/option.{type Option, None}

/// An organization in the system.
pub type Organization {
  Organization(id: Int, name: String, created_at: String)
}

/// A project within an organization.
pub type Project {
  Project(id: Int, org_id: Int, name: String, created_at: String)
}

/// A user's membership in a project.
pub type ProjectMember {
  ProjectMember(
    project_id: Int,
    user_id: Int,
    role: ProjectRole,
    created_at: String,
    claimed_count: Int,
  )
}

/// An organization invitation stored in memory.
pub type OrgInvite {
  OrgInvite(
    code: String,
    org_id: Int,
    created_at_unix: Int,
    expires_at_unix: Option(Int),
    used_at_unix: Option(Int),
    used_by: Option(Int),
  )
}

/// A user stored in memory with credentials.
pub type StoredUser {
  StoredUser(
    id: Int,
    email: String,
    password_hash: String,
    org_id: Int,
    org_role: OrgRole,
    created_at: String,
  )
}

/// The complete in-memory application state.
pub type State {
  State(
    org: Option(Organization),
    next_org_id: Int,
    next_project_id: Int,
    next_user_id: Int,
    users_by_id: dict.Dict(Int, StoredUser),
    user_id_by_email: dict.Dict(String, Int),
    projects_by_id: dict.Dict(Int, Project),
    project_members: dict.Dict(#(Int, Int), ProjectMember),
    invites_by_code: dict.Dict(String, OrgInvite),
  )
}

/// Creates a fresh initial state with no data.
pub fn initial() -> State {
  State(
    org: None,
    next_org_id: 1,
    next_project_id: 1,
    next_user_id: 1,
    users_by_id: dict.new(),
    user_id_by_email: dict.new(),
    projects_by_id: dict.new(),
    project_members: dict.new(),
    invites_by_code: dict.new(),
  )
}
