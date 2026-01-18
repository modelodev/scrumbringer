//// Project domain types for ScrumBringer.
////
//// Defines project and project member structures.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/project.{type Project, type ProjectMember}
////
//// let project = Project(id: 1, name: "My Project", my_role: "admin")
//// ```

// =============================================================================
// Types
// =============================================================================

/// A project in the organization.
///
/// ## Example
///
/// ```gleam
/// Project(id: 1, name: "Sprint Tracker", my_role: "admin")
/// ```
pub type Project {
  Project(id: Int, name: String, my_role: String)
}

/// A member of a project with their role.
///
/// ## Example
///
/// ```gleam
/// ProjectMember(user_id: 1, role: "member", created_at: "2024-01-17T12:00:00Z")
/// ```
pub type ProjectMember {
  ProjectMember(user_id: Int, role: String, created_at: String)
}
