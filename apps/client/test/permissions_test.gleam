import domain/org_role
import domain/project.{Project}
import domain/project_role.{Manager, Member}
import gleam/option
import scrumbringer_client/permissions
import support/domain_fixtures

fn project_with_role(role) {
  Project(..domain_fixtures.project(1, "P1"), my_role: role, members_count: 0)
}

pub fn visible_sections_org_admin_test() {
  let projects = [project_with_role(Member)]

  let assert [
    permissions.Invites,
    permissions.OrgSettings,
    permissions.Projects,
    permissions.Team,
    permissions.ApiTokens,
    permissions.Metrics,
    permissions.Capabilities,
    permissions.Workflows,
  ] = permissions.visible_sections(org_role.Admin, projects)
}

pub fn visible_sections_org_admin_and_project_admin_test() {
  let projects = [project_with_role(Manager)]

  let assert [
    permissions.Invites,
    permissions.OrgSettings,
    permissions.Projects,
    permissions.Team,
    permissions.ApiTokens,
    permissions.Metrics,
    permissions.Members,
    permissions.Capabilities,
    permissions.TaskTypes,
    permissions.Cards,
    permissions.Workflows,
  ] = permissions.visible_sections(org_role.Admin, projects)
}

pub fn visible_sections_project_manager_only_test() {
  let projects = [project_with_role(Manager)]

  // Project managers get primary access to project-scoped configuration.
  let assert [
    permissions.Members,
    permissions.Capabilities,
    permissions.TaskTypes,
    permissions.Cards,
    permissions.Workflows,
  ] = permissions.visible_sections(org_role.Member, projects)
}

pub fn can_access_members_requires_selected_project_or_any_admin_test() {
  let projects = [project_with_role(Manager)]

  let assert True =
    permissions.can_access_section(
      permissions.Members,
      org_role.Member,
      projects,
      option.None,
    )

  let assert False =
    permissions.can_access_section(
      permissions.Members,
      org_role.Member,
      projects,
      option.Some(
        Project(
          ..domain_fixtures.project(2, "P2"),
          my_role: Member,
          members_count: 0,
        ),
      ),
    )
}

pub fn can_access_assignments_admin_only_test() {
  let projects = [project_with_role(Manager)]

  let assert True =
    permissions.can_access_section(
      permissions.Team,
      org_role.Admin,
      projects,
      option.None,
    )

  let assert False =
    permissions.can_access_section(
      permissions.Team,
      org_role.Member,
      projects,
      option.None,
    )
}

pub fn can_manage_project_content_allows_org_admin_without_project_test() {
  let assert True =
    permissions.can_manage_project_content(org_role.Admin, option.None)
}

pub fn is_selected_project_manager_requires_manager_project_test() {
  let assert True =
    permissions.is_selected_project_manager(
      option.Some(project_with_role(Manager)),
    )

  let assert False =
    permissions.is_selected_project_manager(
      option.Some(project_with_role(Member)),
    )

  let assert False = permissions.is_selected_project_manager(option.None)
}

pub fn can_manage_project_content_allows_selected_project_manager_test() {
  let assert True =
    permissions.can_manage_project_content(
      org_role.Member,
      option.Some(project_with_role(Manager)),
    )
}

pub fn can_manage_project_content_rejects_member_and_absent_project_test() {
  let assert False =
    permissions.can_manage_project_content(
      org_role.Member,
      option.Some(project_with_role(Member)),
    )

  let assert False =
    permissions.can_manage_project_content(org_role.Member, option.None)
}
