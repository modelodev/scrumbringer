//// Permission checks for admin functionality.
////
//// Determines which admin sections a user can access based on their
//// organization role and project memberships.
////
//// Permission model:
//// - Org Admin: Can access org-level settings, invites, projects, metrics
//// - Project Manager: Can manage project settings, automations, templates, capabilities, members
//// - Project Member: Can view project content, no admin access

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/org_role.{type OrgRole, Admin}

import domain/project.{type Project, Project}
import domain/project_role.{Manager}

/// Admin panel sections.
pub type AdminSection {
  Invites
  OrgSettings
  Projects
  Team
  ApiTokens
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

/// Returns true if the user is a manager of the project.
pub fn is_project_manager(project: Project) -> Bool {
  case project {
    Project(my_role: Manager, ..) -> True
    _ -> False
  }
}

/// Returns true if the user is manager of any project.
pub fn any_project_manager(projects: List(Project)) -> Bool {
  projects
  |> list.any(is_project_manager)
}

/// Returns true if the selected project exists and the user manages it.
pub fn is_selected_project_manager(selected_project: Option(Project)) -> Bool {
  case selected_project {
    Some(project) -> is_project_manager(project)
    None -> False
  }
}

/// Returns true when the user can edit content in the selected project.
pub fn can_manage_project_content(
  org_role: OrgRole,
  selected_project: Option(Project),
) -> Bool {
  case is_org_admin(org_role) {
    True -> True
    False -> is_selected_project_manager(selected_project)
  }
}

/// Checks if a user can access an admin section.
pub fn can_access_section(
  section: AdminSection,
  org_role: OrgRole,
  projects: List(Project),
  selected_project: Option(Project),
) -> Bool {
  let org_admin = is_org_admin(org_role)
  let any_manager = any_project_manager(projects)

  case section {
    // Org-level sections: only org admin
    Invites | OrgSettings | Projects | Team | ApiTokens | Metrics -> org_admin

    // RuleMetrics: org admin can see org-wide, project managers can see project-level
    RuleMetrics -> org_admin || any_manager

    // Project-scoped sections: requires selected project with manager role
    // Org admin also has implicit manager access to all projects
    Workflows | TaskTemplates | Capabilities | Members | TaskTypes | Cards -> {
      case selected_project {
        Some(project) -> org_admin || is_project_manager(project)
        None -> org_admin || any_manager
      }
    }
  }
}

/// Returns the admin sections visible as primary navigation entries to a user.
pub fn visible_sections(
  org_role: OrgRole,
  projects: List(Project),
) -> List(AdminSection) {
  let any_manager = any_project_manager(projects)

  case is_org_admin(org_role), any_manager {
    // Org admin with manager projects: full access
    True, True -> [
      Invites,
      OrgSettings,
      Projects,
      Team,
      ApiTokens,
      Metrics,
      Members,
      Capabilities,
      TaskTypes,
      Cards,
      Workflows,
    ]
    // Org admin without manager projects: org-level + project-scoped (admin can manage all projects)
    True, False -> [
      Invites,
      OrgSettings,
      Projects,
      Team,
      ApiTokens,
      Metrics,
      Capabilities,
      Workflows,
    ]
    // Project manager (non-org-admin): project-scoped sections only
    False, True -> [
      Members,
      Capabilities,
      TaskTypes,
      Cards,
      Workflows,
    ]
    // No admin access
    False, False -> []
  }
}
