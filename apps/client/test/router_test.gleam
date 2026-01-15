import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleeunit/should

import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router

pub fn parse_admin_members_with_project_test() {
  let parsed = router.parse("/admin/members", "?project=2", "")

  parsed
  |> should.equal(router.Parsed(router.Admin(permissions.Members, Some(2))))
}

pub fn parse_member_pool_with_project_test() {
  let parsed = router.parse("/app/pool", "?project=2", "")

  parsed
  |> should.equal(router.Parsed(router.Member(member_section.Pool, Some(2))))
}

pub fn parse_accept_invite_token_test() {
  let parsed = router.parse("/accept-invite", "?token=il_token", "")

  parsed
  |> should.equal(router.Parsed(router.AcceptInvite("il_token")))
}

pub fn parse_legacy_hash_redirects_to_pathname_test() {
  router.parse("/", "?project=2", "#/admin/members")
  |> should.equal(router.Redirect(router.Admin(permissions.Members, Some(2))))
}

pub fn parse_invalid_project_redirects_and_drops_project_test() {
  let parsed = router.parse("/admin/members", "?project=nope", "")

  parsed
  |> should.equal(router.Redirect(router.Admin(permissions.Members, None)))
}

pub fn mobile_redirects_pool_to_my_bar_test() {
  router.parse("/app/pool", "?project=2", "")
  |> router.apply_mobile_rules(True)
  |> should.equal(router.Redirect(router.Member(member_section.MyBar, Some(2))))
}

pub fn desktop_keeps_pool_route_test() {
  router.parse("/app/pool", "?project=2", "")
  |> router.apply_mobile_rules(False)
  |> should.equal(router.Parsed(router.Member(member_section.Pool, Some(2))))
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

pub fn format_admin_with_project_test() {
  router.format(router.Admin(permissions.Members, Some(2)))
  |> should.equal("/admin/members?project=2")
}

pub fn format_member_pool_with_project_test() {
  router.format(router.Member(member_section.Pool, Some(2)))
  |> should.equal("/app/pool?project=2")
}

pub fn roundtrip_admin_members_test() {
  let route = router.Admin(permissions.Members, Some(2))
  router.format(route) |> parse_formatted |> should.equal(router.Parsed(route))
}

pub fn roundtrip_member_my_bar_without_project_test() {
  let route = router.Member(member_section.MyBar, None)
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
