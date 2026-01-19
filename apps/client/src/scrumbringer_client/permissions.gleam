//// Permission checks for admin functionality.
////
//// Determines which admin sections a user can access based on their
//// organization role and project memberships.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/org_role.{type OrgRole, Admin}

import domain/project.{type Project, Project}

/// Admin panel sections.
pub type AdminSection {
  Invites
  OrgSettings
  Projects
  Metrics
  RuleMetrics
  Members
  Capabilities
  TaskTypes
  Cards
  Workflows
  TaskTemplates
}

/// Returns true if the role has organization admin privileges.
pub fn is_org_admin(role: OrgRole) -> Bool {
  role == Admin
}

/// Returns true if the user is an admin of the project.
pub fn is_project_admin(project: Project) -> Bool {
  case project {
    Project(_, _, "admin") -> True
    _ -> False
  }
}

/// Returns true if the user is admin of any project.
pub fn any_project_admin(projects: List(Project)) -> Bool {
  projects
  |> list.any(is_project_admin)
}

/// Checks if a user can access an admin section.
pub fn can_access_section(
  section: AdminSection,
  org_role: OrgRole,
  projects: List(Project),
  selected_project: Option(Project),
) -> Bool {
  let org_admin = is_org_admin(org_role)
  let any_admin = any_project_admin(projects)

  case section {
    Invites | OrgSettings | Projects | Capabilities | Metrics | RuleMetrics ->
      org_admin

    // Workflows and TaskTemplates: org admin can see org-scoped, project admin can see project-scoped
    Workflows | TaskTemplates -> org_admin || any_admin

    Members | TaskTypes | Cards -> {
      case selected_project {
        Some(project) -> is_project_admin(project)
        None -> any_admin
      }
    }
  }
}

/// Returns the admin sections visible to a user.
pub fn visible_sections(
  org_role: OrgRole,
  projects: List(Project),
) -> List(AdminSection) {
  let any_admin = any_project_admin(projects)

  case is_org_admin(org_role), any_admin {
    True, True -> [
      Invites,
      OrgSettings,
      Projects,
      Metrics,
      RuleMetrics,
      Members,
      Capabilities,
      TaskTypes,
      Cards,
      Workflows,
      TaskTemplates,
    ]
    True, False -> [
      Invites,
      OrgSettings,
      Projects,
      Metrics,
      RuleMetrics,
      Capabilities,
      Workflows,
      TaskTemplates,
    ]
    False, True -> [Members, TaskTypes, Cards, Workflows, TaskTemplates]
    False, False -> []
  }
}
