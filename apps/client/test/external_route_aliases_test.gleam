import gleam/option
import gleeunit/should
import scrumbringer_client/external_route_aliases
import scrumbringer_client/permissions

pub fn org_assignments_alias_points_to_team_test() {
  external_route_aliases.org_section("assignments")
  |> should.equal(option.Some(permissions.Team))
}

pub fn unknown_org_alias_is_not_claimed_test() {
  external_route_aliases.org_section("unknown")
  |> should.equal(option.None)
}
