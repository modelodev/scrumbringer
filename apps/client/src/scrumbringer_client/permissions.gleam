import gleam/list
import gleam/option.{type Option, None, Some}

import scrumbringer_domain/org_role.{type OrgRole, Admin}

import scrumbringer_client/api.{type Project, Project}

pub type AdminSection {
  Invites
  Projects
  Members
  Capabilities
  TaskTypes
}

pub fn is_org_admin(role: OrgRole) -> Bool {
  role == Admin
}

pub fn is_project_admin(project: Project) -> Bool {
  case project {
    Project(_, _, "admin") -> True
    _ -> False
  }
}

pub fn any_project_admin(projects: List(Project)) -> Bool {
  projects
  |> list.any(is_project_admin)
}

pub fn can_access_section(
  section: AdminSection,
  org_role: OrgRole,
  projects: List(Project),
  selected_project: Option(Project),
) -> Bool {
  let org_admin = is_org_admin(org_role)
  let any_admin = any_project_admin(projects)

  case section {
    Invites | Projects | Capabilities -> org_admin

    Members | TaskTypes -> {
      case selected_project {
        Some(project) -> is_project_admin(project)
        None -> any_admin
      }
    }
  }
}

pub fn visible_sections(
  org_role: OrgRole,
  projects: List(Project),
) -> List(AdminSection) {
  let any_admin = any_project_admin(projects)

  case is_org_admin(org_role), any_admin {
    True, True -> [Invites, Projects, Members, Capabilities, TaskTypes]
    True, False -> [Invites, Projects, Capabilities]
    False, True -> [Members, TaskTypes]
    False, False -> []
  }
}
