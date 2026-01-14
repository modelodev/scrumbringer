import gleam/option.{None, Some}
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

pub fn parse_invalid_project_falls_back_to_none_test() {
  let parsed = router.parse("/admin/members", "?project=nope", "")

  parsed
  |> should.equal(router.Parsed(router.Admin(permissions.Members, None)))
}
