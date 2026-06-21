import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/uri

import domain/view_mode
import scrumbringer_client/capability_scope
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/url_state

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

// Story 4.5: New /config/* routes
pub fn parse_config_members_with_project_test() {
  let parsed = router.parse_uri(build_uri("/config/members", "?project=2"))

  assert_equal(
    parsed,
    router.Parsed(router.Config(permissions.Members, Some(2))),
  )
}

pub fn parse_config_unknown_section_redirects_to_members_test() {
  let parsed = router.parse_uri(build_uri("/config/unknown", "?project=2"))

  assert_equal(
    parsed,
    router.Redirect(router.Config(permissions.Members, Some(2))),
  )
}

pub fn parse_config_member_scope_redirects_to_canonical_config_test() {
  let parsed =
    router.parse_uri(build_uri("/config/members", "?project=2&scope=mine"))

  assert_equal(
    parsed,
    router.Redirect(router.Config(permissions.Members, Some(2))),
  )
}

pub fn parse_member_pool_with_project_test() {
  let parsed = router.parse_uri(build_uri("/app/pool", "?project=2"))

  assert_equal(parsed, router.Parsed(member_route(Some(2), None)))
}

pub fn parse_member_unknown_section_redirects_to_pool_test() {
  let parsed = router.parse_uri(build_uri("/app/unknown", "?project=2"))

  assert_equal(parsed, router.Redirect(member_route(Some(2), None)))
}

pub fn parse_accept_invite_token_test() {
  let parsed = router.parse_uri(build_uri("/accept-invite", "?token=il_token"))

  assert_equal(parsed, router.Parsed(router.AcceptInvite("il_token")))
}

pub fn parse_org_assignments_test() {
  let parsed = router.parse_uri(build_uri("/org/assignments", ""))

  assert_equal(parsed, router.Parsed(router.Org(permissions.Team)))
}

pub fn parse_org_team_test() {
  let parsed = router.parse_uri(build_uri("/org/team", ""))

  assert_equal(parsed, router.Parsed(router.Org(permissions.Team)))
}

pub fn parse_org_api_tokens_test() {
  let parsed = router.parse_uri(build_uri("/org/api-tokens", ""))

  assert_equal(parsed, router.Parsed(router.Org(permissions.ApiTokens)))
}

pub fn parse_org_unknown_section_redirects_to_invites_test() {
  let parsed = router.parse_uri(build_uri("/org/unknown", ""))

  assert_equal(parsed, router.Redirect(router.Org(permissions.Invites)))
}

// Story 4.5: Invalid project redirects to Config with None
pub fn parse_invalid_project_redirects_and_drops_project_test() {
  let parsed = router.parse_uri(build_uri("/config/members", "?project=nope"))

  // Invalid project is dropped via redirect
  assert_equal(
    parsed,
    router.Redirect(router.Config(permissions.Members, None)),
  )
}

pub fn parse_member_invalid_view_redirects_test() {
  let parsed = router.parse_uri(build_uri("/app/pool", "?view=nope"))

  assert_equal(parsed, router.Redirect(member_route(None, None)))
}

pub fn parse_member_legacy_list_view_redirects_test() {
  let parsed = router.parse_uri(build_uri("/app/pool", "?view=list"))

  assert_equal(parsed, router.Redirect(member_route(None, None)))
}

pub fn parse_org_assignments_invalid_view_redirects_test() {
  let parsed = router.parse_uri(build_uri("/org/assignments", "?view=pool"))

  assert_equal(parsed, router.Redirect(router.Org(permissions.Team)))
}

// Story 4.4: Mobile keeps pool route in 3-panel layout
pub fn mobile_keeps_pool_route_test() {
  assert_equal(
    router.parse_uri(build_uri("/app/pool", "?project=2")),
    router.Parsed(member_route(Some(2), None)),
  )
}

pub fn desktop_keeps_pool_route_test() {
  assert_equal(
    router.parse_uri(build_uri("/app/pool", "?project=2")),
    router.Parsed(member_route(Some(2), None)),
  )
}

fn parse_formatted(url: String) -> router.ParseResult {
  let parts = string.split(url, "?")
  let assert Ok(pathname) = list.first(parts)
  let search = case list.drop(parts, 1) {
    [] -> ""
    [q, ..] -> "?" <> q
  }

  router.parse_uri(build_uri(pathname, search))
}

pub fn format_login_test() {
  assert_equal(router.format(router.Login), "/")
}

// Story 4.5: Config routes format correctly
pub fn format_config_with_project_test() {
  assert_equal(
    router.format(router.Config(permissions.Members, Some(2))),
    "/config/members?project=2",
  )
}

// Story 4.5: Org routes format correctly
pub fn format_org_invites_test() {
  assert_equal(router.format(router.Org(permissions.Invites)), "/org/invites")
}

pub fn format_org_assignments_test() {
  assert_equal(router.format(router.Org(permissions.Team)), "/org/team")
}

pub fn format_org_api_tokens_test() {
  assert_equal(
    router.format(router.Org(permissions.ApiTokens)),
    "/org/api-tokens",
  )
}

pub fn format_member_pool_with_project_test() {
  assert_equal(
    router.format(member_route(Some(2), None)),
    "/app/pool?project=2",
  )
}

pub fn format_member_people_with_project_test() {
  assert_equal(
    router.format(member_route(Some(2), Some(view_mode.People))),
    "/app/pool?project=2&view=people",
  )
}

pub fn format_member_cards_with_project_test() {
  assert_equal(
    router.format(member_route(Some(2), Some(view_mode.Cards))),
    "/app/pool?project=2&view=cards",
  )
}

pub fn format_member_cards_kanban_with_project_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(2)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_plan_mode(url_state.PlanKanbanParam)

  assert_equal(
    router.format(router.Member(state)),
    "/app/pool?project=2&view=cards&plan_mode=kanban",
  )
}

pub fn format_member_capabilities_with_project_test() {
  assert_equal(
    router.format(member_route(Some(2), Some(view_mode.Capabilities))),
    "/app/pool?project=2&view=capabilities",
  )
}

pub fn format_member_cards_with_scope_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(2)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_capability_scope(capability_scope.MyCapabilities)

  assert_equal(
    router.format(router.Member(state)),
    "/app/pool?project=2&view=cards&scope=mine",
  )
}

// Story 4.5: Config routes roundtrip correctly
pub fn roundtrip_config_members_test() {
  let route = router.Config(permissions.Members, Some(2))
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

// Story 4.5: Org routes roundtrip correctly
pub fn roundtrip_org_invites_test() {
  let route = router.Org(permissions.Invites)
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn roundtrip_org_assignments_test() {
  let route = router.Org(permissions.Team)
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn roundtrip_org_api_tokens_test() {
  let route = router.Org(permissions.ApiTokens)
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn parse_my_bar_route_redirects_to_pool_test() {
  assert_equal(
    router.parse_uri(build_uri("/app/my-bar", "")),
    router.Redirect(member_route(None, None)),
  )
}

pub fn parse_my_skills_route_redirects_to_pool_test() {
  assert_equal(
    router.parse_uri(build_uri("/app/my-skills", "")),
    router.Redirect(member_route(None, None)),
  )
}

pub fn parse_unknown_member_route_redirects_to_pool_test() {
  assert_equal(
    router.parse_uri(build_uri("/app/unknown-member-route", "")),
    router.Redirect(member_route(None, None)),
  )
}

pub fn roundtrip_member_cards_with_project_test() {
  let route = member_route(Some(2), Some(view_mode.Cards))
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn parse_legacy_tracking_view_redirects_to_pool_test() {
  assert_equal(
    router.parse_uri(build_uri("/app/pool", "?project=2&view=hierarchies")),
    router.Redirect(member_route(Some(2), None)),
  )
}

pub fn roundtrip_member_people_with_project_test() {
  let route = member_route(Some(2), Some(view_mode.People))
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn roundtrip_member_capabilities_with_project_test() {
  let route = member_route(Some(2), Some(view_mode.Capabilities))
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn roundtrip_member_cards_with_scope_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(2)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_capability_scope(capability_scope.MyCapabilities)

  let route = router.Member(state)
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn roundtrip_member_cards_kanban_test() {
  let state =
    url_state.empty()
    |> url_state.with_project(2)
    |> url_state.with_view(view_mode.Cards)
    |> url_state.with_plan_mode(url_state.PlanKanbanParam)

  let route = router.Member(state)
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn roundtrip_accept_invite_test() {
  let route = router.AcceptInvite("il_token")
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

pub fn roundtrip_reset_password_test() {
  let route = router.ResetPassword("rp_token")
  assert_equal(router.format(route) |> parse_formatted, router.Parsed(route))
}

fn build_uri(pathname: String, search: String) -> uri.Uri {
  let query = case search {
    "" -> None
    _ -> Some(string.drop_start(search, 1))
  }
  uri.Uri(
    scheme: None,
    userinfo: None,
    host: None,
    port: None,
    path: pathname,
    query: query,
    fragment: None,
  )
}

fn member_route(
  project_id: Option(Int),
  view_mode: Option(view_mode.ViewMode),
) -> router.Route {
  let state = case project_id {
    Some(id) -> url_state.with_project(url_state.empty(), id)
    None -> url_state.empty()
  }
  let state = case view_mode {
    Some(mode) -> url_state.with_view(state, mode)
    None -> state
  }
  router.Member(state)
}
