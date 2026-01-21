import gleam/option
import gleeunit/should
import domain/project.{Project}
import scrumbringer_client/permissions
import domain/org_role

pub fn visible_sections_org_admin_test() {
  let projects = [Project(id: 1, name: "P1", my_role: "member")]

  permissions.visible_sections(org_role.Admin, projects)
  |> should.equal([
    permissions.Invites,
    permissions.OrgSettings,
    permissions.Projects,
    permissions.Metrics,
    permissions.RuleMetrics,
    permissions.Capabilities,
    permissions.Workflows,
    permissions.TaskTemplates,
  ])
}

pub fn visible_sections_org_admin_and_project_admin_test() {
  let projects = [Project(id: 1, name: "P1", my_role: "manager")]

  permissions.visible_sections(org_role.Admin, projects)
  |> should.equal([
    permissions.Invites,
    permissions.OrgSettings,
    permissions.Projects,
    permissions.Metrics,
    permissions.RuleMetrics,
    permissions.Members,
    permissions.Capabilities,
    permissions.TaskTypes,
    permissions.Cards,
    permissions.Workflows,
    permissions.TaskTemplates,
  ])
}

pub fn visible_sections_project_manager_only_test() {
  let projects = [Project(id: 1, name: "P1", my_role: "manager")]

  // Project managers get access to project-scoped sections including capabilities
  permissions.visible_sections(org_role.Member, projects)
  |> should.equal([
    permissions.RuleMetrics,
    permissions.Members,
    permissions.Capabilities,
    permissions.TaskTypes,
    permissions.Cards,
    permissions.Workflows,
    permissions.TaskTemplates,
  ])
}

pub fn can_access_members_requires_selected_project_or_any_admin_test() {
  let projects = [Project(id: 1, name: "P1", my_role: "manager")]

  permissions.can_access_section(
    permissions.Members,
    org_role.Member,
    projects,
    option.None,
  )
  |> should.equal(True)

  permissions.can_access_section(
    permissions.Members,
    org_role.Member,
    projects,
    option.Some(Project(id: 2, name: "P2", my_role: "member")),
  )
  |> should.equal(False)
}
