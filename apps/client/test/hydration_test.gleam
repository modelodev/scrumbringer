import gleam/option.{type Option, None, Some}
import support/assertions.{assert_equal}

import domain/org_role
import scrumbringer_client/automation_deep_link
import scrumbringer_client/hydration
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/url_state

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
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(
    hydration.plan(router.Config(permissions.Members, Some(2)), snap),
    [hydration.FetchMe],
  )
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
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(
    hydration.plan(router.Config(permissions.Members, Some(2)), snap),
    [
      hydration.FetchProjects,
      hydration.FetchInviteLinks,
      hydration.FetchCapabilities,
      hydration.FetchMeMetrics,
      hydration.FetchWorkSessions,
    ],
  )

  let snap_with_projects =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Admin),
      projects: hydration.Loaded,
      is_any_project_manager: True,
      invite_links: hydration.Loaded,
      capabilities: hydration.Loaded,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(
    hydration.plan(
      router.Config(permissions.Members, Some(2)),
      snap_with_projects,
    ),
    [
      hydration.FetchMeMetrics,
      hydration.FetchWorkSessions,
      hydration.FetchMembers(project_id: 2),
    ],
  )
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
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(hydration.plan(router.Org(permissions.Invites), snap), [
    hydration.Redirect(to: member_route(None)),
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
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(
    hydration.plan(router.Config(permissions.Members, Some(8)), snap),
    [hydration.FetchProjects],
  )
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
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  // Should NOT redirect - should fetch members instead
  assert_equal(
    hydration.plan(router.Config(permissions.Members, Some(8)), snap),
    [
      hydration.FetchCapabilities,
      hydration.FetchMeMetrics,
      hydration.FetchWorkSessions,
      hydration.FetchMembers(project_id: 8),
    ],
  )
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
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  // Should redirect because Invites is org-level
  assert_equal(hydration.plan(router.Org(permissions.Invites), snap), [
    hydration.Redirect(to: member_route(None)),
  ])
}

pub fn automation_deep_link_non_manager_redirect_preserves_project_test() {
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.Loaded,
      is_any_project_manager: False,
      invite_links: hydration.Loaded,
      capabilities: hydration.Loaded,
      my_capability_ids: hydration.Loaded,
      org_settings_users: hydration.NotAsked,
      org_users_cache: hydration.Loaded,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.Loaded,
      me_metrics: hydration.Loaded,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(
    hydration.plan(
      router.ConfigAutomation(
        permissions.Workflows,
        Some(8),
        automation_deep_link.SelectedRule(21, Some(3)),
      ),
      snap,
    ),
    [hydration.Redirect(to: member_route(Some(8)))],
  )
}

pub fn task_show_deep_link_cold_start_hydrates_member_resources_test() {
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.NotAsked,
      is_any_project_manager: False,
      invite_links: hydration.NotAsked,
      capabilities: hydration.NotAsked,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(hydration.plan(task_show_route(Some(8), 55), snap), [
    hydration.FetchProjects,
    hydration.FetchCapabilities,
    hydration.FetchMeCapabilityIds,
    hydration.FetchWorkSessions,
    hydration.FetchMeMetrics,
    hydration.FetchOrgUsersCache,
    hydration.RefreshMember,
  ])
}

pub fn card_show_deep_link_cold_start_hydrates_member_resources_test() {
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.NotAsked,
      is_any_project_manager: False,
      invite_links: hydration.NotAsked,
      capabilities: hydration.NotAsked,
      my_capability_ids: hydration.NotAsked,
      org_settings_users: hydration.NotAsked,
      org_users_cache: hydration.NotAsked,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(hydration.plan(card_show_route(Some(8), 42), snap), [
    hydration.FetchProjects,
    hydration.FetchCapabilities,
    hydration.FetchMeCapabilityIds,
    hydration.FetchWorkSessions,
    hydration.FetchMeMetrics,
    hydration.FetchOrgUsersCache,
    hydration.RefreshMember,
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
      // AC7: Set to Loaded since this test verifies minimal refresh scenario
      org_users_cache: hydration.Loaded,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.NotAsked,
      task_types_project_id: None,
      member_tasks: hydration.NotAsked,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.NotAsked,
      me_metrics: hydration.NotAsked,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(hydration.plan(member_route(Some(2)), snap), [
    hydration.FetchWorkSessions,
    hydration.FetchMeMetrics,
    hydration.RefreshMember,
  ])
}

pub fn member_pool_refreshes_when_cards_missing_test() {
  let snap =
    hydration.Snapshot(
      auth: hydration.Authed(org_role.Member),
      projects: hydration.Loaded,
      is_any_project_manager: False,
      invite_links: hydration.Loaded,
      capabilities: hydration.Loaded,
      my_capability_ids: hydration.Loaded,
      org_settings_users: hydration.NotAsked,
      org_users_cache: hydration.Loaded,
      integration_users: hydration.NotAsked,
      api_tokens: hydration.NotAsked,
      members: hydration.NotAsked,
      members_project_id: None,
      task_types: hydration.Loaded,
      task_types_project_id: None,
      member_tasks: hydration.Loaded,
      member_cards: hydration.NotAsked,
      work_sessions: hydration.Loaded,
      me_metrics: hydration.Loaded,
      org_metrics_overview: hydration.NotAsked,
      org_metrics_project_tasks: hydration.NotAsked,
      org_metrics_project_id: None,
    )

  assert_equal(hydration.plan(member_route(Some(2)), snap), [
    hydration.RefreshMember,
  ])
}

fn member_route(project_id: Option(Int)) -> router.Route {
  let state = case project_id {
    Some(id) -> url_state.with_project(url_state.empty(), id)
    None -> url_state.empty()
  }
  router.Member(state)
}

fn task_show_route(project_id: Option(Int), task_id: Int) -> router.Route {
  let state = case project_id {
    Some(id) -> url_state.with_project(url_state.empty(), id)
    None -> url_state.empty()
  }

  router.Member(url_state.with_task_show(state, task_id))
}

fn card_show_route(project_id: Option(Int), card_id: Int) -> router.Route {
  let state = case project_id {
    Some(id) -> url_state.with_project(url_state.empty(), id)
    None -> url_state.empty()
  }

  router.Member(url_state.with_card_show(state, card_id))
}
