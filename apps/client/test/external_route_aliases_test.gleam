import gleam/option
import scrumbringer_client/external_route_aliases
import scrumbringer_client/permissions

pub fn config_templates_alias_points_to_members_test() {
  let assert option.Some(permissions.Members) =
    external_route_aliases.config_section("templates")
}

pub fn config_rule_metrics_alias_points_to_members_test() {
  let assert option.Some(permissions.Members) =
    external_route_aliases.config_section("rule-metrics")
}

pub fn unknown_config_alias_is_not_claimed_test() {
  let assert option.None = external_route_aliases.config_section("unknown")
}

pub fn org_assignments_alias_points_to_team_test() {
  let assert option.Some(permissions.Team) =
    external_route_aliases.org_section("assignments")
}

pub fn unknown_org_alias_is_not_claimed_test() {
  let assert option.None = external_route_aliases.org_section("unknown")
}
