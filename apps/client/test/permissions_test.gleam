import gleam/option
import gleeunit/should
import scrumbringer_client/api
import scrumbringer_client/permissions
import scrumbringer_domain/org_role

pub fn visible_sections_org_admin_test() {
  let projects = [api.Project(id: 1, name: "P1", my_role: "member")]

  permissions.visible_sections(org_role.Admin, projects)
  |> should.equal([
    permissions.Invites,
    permissions.OrgSettings,
    permissions.Projects,
    permissions.Capabilities,
  ])
}

pub fn visible_sections_org_admin_and_project_admin_test() {
  let projects = [api.Project(id: 1, name: "P1", my_role: "admin")]

  permissions.visible_sections(org_role.Admin, projects)
  |> should.equal([
    permissions.Invites,
    permissions.OrgSettings,
    permissions.Projects,
    permissions.Members,
    permissions.Capabilities,
    permissions.TaskTypes,
  ])
}

pub fn visible_sections_project_admin_only_test() {
  let projects = [api.Project(id: 1, name: "P1", my_role: "admin")]

  permissions.visible_sections(org_role.Member, projects)
  |> should.equal([permissions.Members, permissions.TaskTypes])
}

pub fn can_access_members_requires_selected_project_or_any_admin_test() {
  let projects = [api.Project(id: 1, name: "P1", my_role: "admin")]

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
    option.Some(api.Project(id: 2, name: "P2", my_role: "member")),
  )
  |> should.equal(False)
}
