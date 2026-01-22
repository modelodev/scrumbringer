import gleam/option.{None, Some}
import gleeunit/should

import scrumbringer_client/hydration
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import domain/org_role

pub fn admin_members_unknown_auth_requires_fetch_me_test() {
  let snap =
    hydration.Snapshot(
      auth: hydration.Unknown,
      projects: hydration.NotAsked,
      is_any_project_manager: False,
      invite_links: hydration.NotAsked,
      capabilities: hydration.NotAsked,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      active_task: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  hydration.plan(router.Admin(permissions.Members, Some(2)), snap)
  |> should.equal([hydration.FetchMe])
}

pub fn admin_members_authed_admin_plans_projects_then_members_test() {
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Admin),
      projects: hydration.NotAsked,
      is_any_project_manager: False,
      invite_links: hydration.NotAsked,
      capabilities: hydration.NotAsked,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      active_task: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  hydration.plan(router.Admin(permissions.Members, Some(2)), snap)
  |> should.equal([
    hydration.FetchProjects,
    hydration.FetchInviteLinks,
    hydration.FetchCapabilities,
  ])

  let snap_with_projects =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Admin),
      projects: hydration.Loaded,
      is_any_project_manager: True,
      invite_links: hydration.Loaded,
      capabilities: hydration.Loaded,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      active_task: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  hydration.plan(router.Admin(permissions.Members, Some(2)), snap_with_projects)
  |> should.equal([hydration.FetchMembers(project_id: 2)])
}

pub fn admin_route_non_admin_redirects_to_member_pool_test() {
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.Loaded,
      is_any_project_manager: False,
      invite_links: hydration.Loaded,
      capabilities: hydration.Loaded,
      my_capability_ids: hydration.Loaded,
      org_settings_users: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      active_task: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  hydration.plan(router.Admin(permissions.Invites, Some(2)), snap)
  |> should.equal([
    hydration.Redirect(to: router.Member(member_section.Pool, Some(2), None)),
  ])
}

pub fn admin_members_project_manager_not_loaded_fetches_projects_test() {
  // PM (org_role.Member) trying to access Members section with projects not loaded
  // Should fetch projects first before deciding access
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.NotAsked,
      is_any_project_manager: False,
      invite_links: hydration.NotAsked,
      capabilities: hydration.NotAsked,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      active_task: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  hydration.plan(router.Admin(permissions.Members, Some(8)), snap)
  |> should.equal([hydration.FetchProjects])
}

pub fn admin_members_project_manager_loaded_grants_access_test() {
  // PM (org_role.Member) with projects loaded and is_any_project_manager = True
  // Should allow access to project-scoped sections like Members
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.Loaded,
      is_any_project_manager: True,
      invite_links: hydration.NotAsked,
      capabilities: hydration.NotAsked,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      active_task: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  // Should NOT redirect - should fetch members instead
  hydration.plan(router.Admin(permissions.Members, Some(8)), snap)
  |> should.equal([
    hydration.FetchCapabilities,
    hydration.FetchMembers(project_id: 8),
  ])
}

pub fn admin_org_level_section_pm_redirects_test() {
  // PM (org_role.Member) trying to access org-level section (Invites)
  // Should redirect even if they're a project manager
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.Loaded,
      is_any_project_manager: True,
      invite_links: hydration.NotAsked,
      capabilities: hydration.NotAsked,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      active_task: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  // Should redirect because Invites is org-level
  hydration.plan(router.Admin(permissions.Invites, Some(8)), snap)
  |> should.equal([
    hydration.Redirect(to: router.Member(member_section.Pool, Some(8), None)),
  ])
}

pub fn member_pool_with_projects_loaded_only_refreshes_member_test() {
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.Loaded,
      is_any_project_manager: False,
      invite_links: hydration.Loaded,
      capabilities: hydration.Loaded,
      my_capability_ids: hydration.Loaded,
      org_settings_users: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      active_task: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  hydration.plan(router.Member(member_section.Pool, Some(2), None), snap)
  |> should.equal([
    hydration.FetchActiveTask,
    hydration.FetchMeMetrics,
    hydration.RefreshMember,
  ])
}
