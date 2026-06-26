//// Pure route derivations for the left navigation panel.

import domain/org.{type InviteLink}
import domain/remote.{type Remote, Loaded}
import domain/view_mode.{type ViewMode}
import gleam/list
import gleam/option.{type Option, None, Some}
import scrumbringer_client/capability_scope.{type CapabilityScope}
import scrumbringer_client/features/pool/member_route_policy
import scrumbringer_client/permissions.{type AdminSection}
import scrumbringer_client/router
import scrumbringer_client/url_state

pub type MemberRouteConfig {
  MemberRouteConfig(
    selected_project_id: Option(Int),
    view_mode: ViewMode,
    capability_scope: CapabilityScope,
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search: Option(String),
    card_depth: Option(Int),
    plan_mode: url_state.PlanModeParam,
  )
}

pub fn member_state(
  config: MemberRouteConfig,
  mode: ViewMode,
) -> url_state.UrlState {
  member_route_policy.state(
    config.selected_project_id,
    destination_for_mode(mode, config.plan_mode),
    filters(config),
  )
}

pub fn member_route(config: MemberRouteConfig, mode: ViewMode) -> router.Route {
  router.Member(member_state(config, mode))
}

pub fn member_plan_route(config: MemberRouteConfig) -> router.Route {
  router.Member(member_route_policy.state(
    config.selected_project_id,
    member_route_policy.PlanStructureDestination,
    filters(config),
  ))
}

pub fn member_kanban_route(config: MemberRouteConfig) -> router.Route {
  router.Member(member_route_policy.state(
    config.selected_project_id,
    member_route_policy.PlanKanbanDestination,
    filters(config),
  ))
}

pub fn member_depth_route(config: MemberRouteConfig, depth: Int) -> router.Route {
  router.Member(
    member_route_policy.state(
      config.selected_project_id,
      member_route_policy.PlanStructureDestination,
      filters(config),
    )
    |> url_state.with_card_depth(Some(depth)),
  )
}

pub fn current_member_route(config: MemberRouteConfig) -> router.Route {
  let state =
    member_state(config, config.view_mode)
    |> url_state.with_card_depth(config.card_depth)

  case config.view_mode {
    view_mode.Cards ->
      router.Member(url_state.with_plan_mode(state, config.plan_mode))
    _ -> router.Member(state)
  }
}

pub fn admin_route(
  section: AdminSection,
  selected_project_id: Option(Int),
) -> router.Route {
  case is_org_section(section) {
    True -> router.Org(section)
    False -> router.Config(section, selected_project_id)
  }
}

pub fn pending_invites_count(invite_links: Remote(List(InviteLink))) -> Int {
  case invite_links {
    Loaded(links) -> list.count(links, fn(link) { link.used_at == None })
    _ -> 0
  }
}

pub fn loaded_count(remote_list: Remote(List(a))) -> Int {
  case remote_list {
    Loaded(items) -> list.length(items)
    _ -> 0
  }
}

fn destination_for_mode(
  mode: ViewMode,
  plan_mode: url_state.PlanModeParam,
) -> member_route_policy.Destination {
  case mode {
    view_mode.Pool -> member_route_policy.PoolDestination
    view_mode.Capabilities -> member_route_policy.CapabilitiesDestination
    view_mode.People -> member_route_policy.PeopleDestination
    view_mode.Cards ->
      case plan_mode {
        url_state.PlanKanbanParam -> member_route_policy.PlanKanbanDestination
        url_state.PlanStructureParam ->
          member_route_policy.PlanStructureDestination
      }
  }
}

fn filters(config: MemberRouteConfig) -> member_route_policy.WorkFilters {
  member_route_policy.WorkFilters(
    capability_scope: config.capability_scope,
    type_filter: config.type_filter,
    capability_filter: config.capability_filter,
    search: config.search,
  )
}

fn is_org_section(section: AdminSection) -> Bool {
  case section {
    permissions.Invites
    | permissions.OrgSettings
    | permissions.Projects
    | permissions.Team
    | permissions.ApiTokens
    | permissions.Metrics -> True
    _ -> False
  }
}
