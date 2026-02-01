//// Project domain types for ScrumBringer.
////
//// Defines project and project member structures.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/project.{type Project, type ProjectMember}
//// import shared/domain/project_role.{Manager}
////
//// let project = Project(id: 1, name: "My Project", my_role: Manager)
//// ```

import domain/project_role.{type ProjectRole}

// =============================================================================
// Types
// =============================================================================

/// A project in the organization.
///
/// ## Example
///
/// ```gleam
/// Project(id: 1, name: "Sprint Tracker", my_role: Manager, created_at: "2026-01-15", members_count: 5)
/// ```
pub type Project {
  Project(
    id: Int,
    name: String,
    my_role: ProjectRole,
    created_at: String,
    members_count: Int,
  )
}

/// A member of a project with their role.
///
/// ## Example
///
/// ```gleam
/// ProjectMember(user_id: 1, role: Member, created_at: "2024-01-17T12:00:00Z", claimed_count: 0)
/// ```
pub type ProjectMember {
  ProjectMember(
    user_id: Int,
    role: ProjectRole,
    created_at: String,
    claimed_count: Int,
  )
}
