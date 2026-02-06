import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import gleeunit/should

import domain/view_mode
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/url_state

// Story 4.5: New /config/* routes
pub fn parse_config_members_with_project_test() {
  let parsed = router.parse_uri(build_uri("/config/members", "?project=2"))

  parsed
  |> should.equal(router.Parsed(router.Config(permissions.Members, Some(2))))
}

pub fn parse_member_pool_with_project_test() {
  let parsed = router.parse_uri(build_uri("/app/pool", "?project=2"))

  parsed
  |> should.equal(
    router.Parsed(member_route(member_section.Pool, Some(2), None)),
  )
}

pub fn parse_accept_invite_token_test() {
  let parsed = router.parse_uri(build_uri("/accept-invite", "?token=il_token"))

  parsed
  |> should.equal(router.Parsed(router.AcceptInvite("il_token")))
}

pub fn parse_org_assignments_test() {
  let parsed = router.parse_uri(build_uri("/org/assignments", ""))

  parsed
  |> should.equal(router.Parsed(router.Org(permissions.Assignments)))
}

// Story 4.5: Invalid project redirects to Config with None
pub fn parse_invalid_project_redirects_and_drops_project_test() {
  let parsed = router.parse_uri(build_uri("/config/members", "?project=nope"))

  // Invalid project is dropped via redirect
  parsed
  |> should.equal(router.Redirect(router.Config(permissions.Members, None)))
}

pub fn parse_member_invalid_view_redirects_test() {
  let parsed = router.parse_uri(build_uri("/app/pool", "?view=nope"))

  parsed
  |> should.equal(
    router.Redirect(member_route(member_section.Pool, None, None)),
  )
}

pub fn parse_org_assignments_invalid_view_redirects_test() {
  let parsed = router.parse_uri(build_uri("/org/assignments", "?view=pool"))

  parsed
  |> should.equal(router.Redirect(router.Org(permissions.Assignments)))
}

// Story 4.4: Mobile keeps pool route in 3-panel layout
pub fn mobile_keeps_pool_route_test() {
  router.parse_uri(build_uri("/app/pool", "?project=2"))
  |> router.apply_mobile_rules(True)
  |> should.equal(
    router.Parsed(member_route(member_section.Pool, Some(2), None)),
  )
}

pub fn desktop_keeps_pool_route_test() {
  router.parse_uri(build_uri("/app/pool", "?project=2"))
  |> router.apply_mobile_rules(False)
  |> should.equal(
    router.Parsed(member_route(member_section.Pool, Some(2), None)),
  )
}

fn parse_formatted(url: String) -> router.ParseResult {
  let parts = string.split(url, "?")
  let pathname = parts |> list.first |> result.unwrap("/")
  let search = case list.drop(parts, 1) {
    [] -> ""
    [q, ..] -> "?" <> q
  }

  router.parse_uri(build_uri(pathname, search))
}

pub fn format_login_test() {
  router.format(router.Login) |> should.equal("/")
}

// Story 4.5: Config routes format correctly
pub fn format_config_with_project_test() {
  router.format(router.Config(permissions.Members, Some(2)))
  |> should.equal("/config/members?project=2")
}

// Story 4.5: Org routes format correctly
pub fn format_org_invites_test() {
  router.format(router.Org(permissions.Invites))
  |> should.equal("/org/invites")
}

pub fn format_org_assignments_test() {
  router.format(router.Org(permissions.Assignments))
  |> should.equal("/org/assignments")
}

pub fn format_member_pool_with_project_test() {
  router.format(member_route(member_section.Pool, Some(2), None))
  |> should.equal("/app/pool?project=2")
}

pub fn format_member_list_with_project_test() {
  router.format(member_route(member_section.Pool, Some(2), Some(view_mode.List)))
  |> should.equal("/app/pool?project=2&view=list")
}

// Story 4.5: Config routes roundtrip correctly
pub fn roundtrip_config_members_test() {
  let route = router.Config(permissions.Members, Some(2))
  router.format(route) |> parse_formatted |> should.equal(router.Parsed(route))
}

// Story 4.5: Org routes roundtrip correctly
pub fn roundtrip_org_invites_test() {
  let route = router.Org(permissions.Invites)
  router.format(route) |> parse_formatted |> should.equal(router.Parsed(route))
}

pub fn roundtrip_org_assignments_test() {
  let route = router.Org(permissions.Assignments)
  router.format(route) |> parse_formatted |> should.equal(router.Parsed(route))
}

pub fn parse_my_bar_route_test() {
  router.parse_uri(build_uri("/app/my-bar", ""))
  |> should.equal(router.Parsed(member_route(member_section.MyBar, None, None)))
}

pub fn parse_my_skills_route_test() {
  router.parse_uri(build_uri("/app/my-skills", ""))
  |> should.equal(
    router.Parsed(member_route(member_section.MySkills, None, None)),
  )
}

// Fichas is still valid
pub fn roundtrip_member_fichas_without_project_test() {
  let route = member_route(member_section.Fichas, None, None)
  router.format(route) |> parse_formatted |> should.equal(router.Parsed(route))
}

pub fn roundtrip_member_list_with_project_test() {
  let route = member_route(member_section.Pool, Some(2), Some(view_mode.List))
  router.format(route) |> parse_formatted |> should.equal(router.Parsed(route))
}

pub fn roundtrip_accept_invite_test() {
  let route = router.AcceptInvite("il_token")
  router.format(route) |> parse_formatted |> should.equal(router.Parsed(route))
}

pub fn roundtrip_reset_password_test() {
  let route = router.ResetPassword("rp_token")
  router.format(route) |> parse_formatted |> should.equal(router.Parsed(route))
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
  section: member_section.MemberSection,
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
  router.Member(section, state)
}
