import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleeunit/should

import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router

// Story 4.5: /admin/* redirects to /config/* or /org/*
pub fn parse_admin_members_redirects_to_config_test() {
  let parsed = router.parse("/admin/members", "?project=2", "")

  // Admin routes now redirect to Config routes
  parsed
  |> should.equal(router.Redirect(router.Config(permissions.Members, Some(2))))
}

// Story 4.5: New /config/* routes
pub fn parse_config_members_with_project_test() {
  let parsed = router.parse("/config/members", "?project=2", "")

  parsed
  |> should.equal(router.Parsed(router.Config(permissions.Members, Some(2))))
}

pub fn parse_member_pool_with_project_test() {
  let parsed = router.parse("/app/pool", "?project=2", "")

  parsed
  |> should.equal(router.Parsed(router.Member(member_section.Pool, Some(2), None)))
}

pub fn parse_accept_invite_token_test() {
  let parsed = router.parse("/accept-invite", "?token=il_token", "")

  parsed
  |> should.equal(router.Parsed(router.AcceptInvite("il_token")))
}

// Story 4.5: Legacy hash routes also redirect to Config
pub fn parse_legacy_hash_redirects_to_config_test() {
  router.parse("/", "?project=2", "#/admin/members")
  |> should.equal(router.Redirect(router.Config(permissions.Members, Some(2))))
}

// Story 4.5: Invalid project redirects to Config with None
pub fn parse_invalid_project_redirects_and_drops_project_test() {
  let parsed = router.parse("/admin/members", "?project=nope", "")

  // Admin routes redirect to Config, and invalid project is dropped
  parsed
  |> should.equal(router.Redirect(router.Config(permissions.Members, None)))
}

// Story 4.4: Mobile no longer redirects to my-bar since it's deprecated
// Pool is the main view in the new 3-panel layout
pub fn mobile_keeps_pool_route_test() {
  router.parse("/app/pool", "?project=2", "")
  |> router.apply_mobile_rules(True)
  |> should.equal(router.Parsed(router.Member(member_section.Pool, Some(2), None)))
}

pub fn desktop_keeps_pool_route_test() {
  router.parse("/app/pool", "?project=2", "")
  |> router.apply_mobile_rules(False)
  |> should.equal(router.Parsed(router.Member(member_section.Pool, Some(2), None)))
}

fn parse_formatted(url: String) -> router.ParseResult {
  let parts = string.split(url, "?")
  let pathname = parts |> list.first |> result.unwrap("/")
  let search = case list.drop(parts, 1) {
    [] -> ""
    [q, ..] -> "?" <> q
  }

  router.parse(pathname, search, "")
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

pub fn format_member_pool_with_project_test() {
  router.format(router.Member(member_section.Pool, Some(2), None))
  |> should.equal("/app/pool?project=2")
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

// Story 4.5: Admin routes still format to /admin/* but parsing redirects
pub fn format_admin_formats_to_admin_path_test() {
  let route = router.Admin(permissions.Members, Some(2))
  router.format(route) |> should.equal("/admin/members?project=2")
}

// Story 4.4: my-bar is deprecated and redirects to Pool
pub fn deprecated_my_bar_redirects_to_pool_test() {
  // Parsing /app/my-bar now redirects to Pool
  router.parse("/app/my-bar", "", "")
  |> should.equal(router.Redirect(router.Member(member_section.Pool, None, None)))
}

// Story 4.4: my-skills is deprecated and redirects to Pool
pub fn deprecated_my_skills_redirects_to_pool_test() {
  router.parse("/app/my-skills", "", "")
  |> should.equal(router.Redirect(router.Member(member_section.Pool, None, None)))
}

// Fichas is still valid
pub fn roundtrip_member_fichas_without_project_test() {
  let route = router.Member(member_section.Fichas, None, None)
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
