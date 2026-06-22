import domain/org.{Active, InviteLink}
import domain/remote.{Loaded, NotAsked}
import domain/view_mode
import gleam/option.{type Option, None, Some}
import scrumbringer_client/capability_scope
import scrumbringer_client/features/layout/left_panel_data
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/url_state

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

fn base_config() -> left_panel_data.MemberRouteConfig {
  left_panel_data.MemberRouteConfig(
    selected_project_id: Some(42),
    view_mode: view_mode.Pool,
    capability_scope: capability_scope.MyCapabilities,
    type_filter: Some(7),
    capability_filter: Some(9),
    search: Some("sync"),
    card_depth: None,
    plan_mode: url_state.PlanStructureParam,
  )
}

fn invite_link(email: String, used_at: Option(String)) {
  InviteLink(
    email: email,
    token: "token-" <> email,
    url_path: "/accept-invite",
    state: Active,
    created_at: "2026-06-08T00:00:00Z",
    used_at: used_at,
    invalidated_at: None,
  )
}

pub fn member_route_preserves_project_filters_and_search_test() {
  let route = left_panel_data.member_route(base_config(), view_mode.Cards)
  let assert router.Member(state) = route

  state |> url_state.project |> assert_equal(Some(42))
  state |> url_state.view |> assert_equal(view_mode.Cards)
  state
  |> url_state.capability_scope
  |> assert_equal(capability_scope.MyCapabilities)
  state |> url_state.type_filter |> assert_equal(Some(7))
  state |> url_state.capability_filter |> assert_equal(Some(9))
  state |> url_state.search |> assert_equal(Some("sync"))
  state |> url_state.card_depth |> assert_equal(None)
}

pub fn member_depth_route_sets_cards_view_and_depth_test() {
  let route = left_panel_data.member_depth_route(base_config(), 2)
  let assert router.Member(state) = route

  state |> url_state.project |> assert_equal(Some(42))
  state |> url_state.view |> assert_equal(view_mode.Cards)
  state |> url_state.card_depth |> assert_equal(Some(2))
}

pub fn current_member_route_uses_member_state_test() {
  let config =
    left_panel_data.MemberRouteConfig(
      ..base_config(),
      view_mode: view_mode.Capabilities,
    )

  let route = left_panel_data.current_member_route(config)
  let assert router.Member(state) = route

  state |> url_state.view |> assert_equal(view_mode.Capabilities)
}

pub fn current_member_route_preserves_plan_mode_for_cards_test() {
  let config =
    left_panel_data.MemberRouteConfig(
      ..base_config(),
      view_mode: view_mode.Cards,
      plan_mode: url_state.PlanKanbanParam,
    )

  let route = left_panel_data.current_member_route(config)
  let assert router.Member(state) = route

  state |> url_state.view |> assert_equal(view_mode.Cards)
  state |> url_state.plan_mode |> assert_equal(url_state.PlanKanbanParam)
}

pub fn member_state_omits_optional_values_when_absent_test() {
  let config =
    left_panel_data.MemberRouteConfig(
      ..base_config(),
      selected_project_id: None,
      type_filter: None,
      capability_filter: None,
      search: None,
      card_depth: None,
      plan_mode: url_state.PlanStructureParam,
    )

  let state = left_panel_data.member_state(config, view_mode.People)

  state |> url_state.project |> assert_equal(None)
  state |> url_state.type_filter |> assert_equal(None)
  state |> url_state.capability_filter |> assert_equal(None)
  state |> url_state.search |> assert_equal(None)
}

pub fn admin_route_uses_org_route_for_org_sections_test() {
  let assert router.Org(permissions.Invites) =
    left_panel_data.admin_route(permissions.Invites, Some(42))
  let assert router.Org(permissions.OrgSettings) =
    left_panel_data.admin_route(permissions.OrgSettings, Some(42))
  let assert router.Org(permissions.ApiTokens) =
    left_panel_data.admin_route(permissions.ApiTokens, Some(42))
  let assert router.Org(permissions.Metrics) =
    left_panel_data.admin_route(permissions.Metrics, Some(42))
}

pub fn admin_route_uses_config_route_for_project_sections_test() {
  let assert router.Config(permissions.Members, Some(42)) =
    left_panel_data.admin_route(permissions.Members, Some(42))
  let assert router.Config(permissions.RuleMetrics, Some(42)) =
    left_panel_data.admin_route(permissions.RuleMetrics, Some(42))
}

pub fn pending_invites_count_counts_only_unused_loaded_links_test() {
  let links =
    Loaded([
      invite_link("pending@example.com", None),
      invite_link("used@example.com", Some("2026-06-08T01:00:00Z")),
      invite_link("pending-2@example.com", None),
    ])

  left_panel_data.pending_invites_count(links)
  |> assert_equal(2)
}

pub fn pending_invites_count_defaults_to_zero_when_not_loaded_test() {
  left_panel_data.pending_invites_count(NotAsked)
  |> assert_equal(0)
}

pub fn loaded_count_counts_loaded_items_and_defaults_to_zero_test() {
  left_panel_data.loaded_count(Loaded([1, 2, 3]))
  |> assert_equal(3)

  left_panel_data.loaded_count(NotAsked)
  |> assert_equal(0)
}
