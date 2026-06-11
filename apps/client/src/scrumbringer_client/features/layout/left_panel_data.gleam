//// Pure route derivations for the left navigation panel.

import domain/org.{type InviteLink}
import domain/remote.{type Remote, Loaded}
import domain/view_mode.{type ViewMode}
import gleam/list
import gleam/option.{type Option, None, Some}
import scrumbringer_client/capability_scope.{type CapabilityScope}
import scrumbringer_client/member_section.{type MemberSection}
import scrumbringer_client/permissions.{type AdminSection}
import scrumbringer_client/router
import scrumbringer_client/url_state

pub type MemberRouteConfig {
  MemberRouteConfig(
    selected_project_id: Option(Int),
    member_section: MemberSection,
    view_mode: ViewMode,
    capability_scope: CapabilityScope,
    type_filter: Option(Int),
    capability_filter: Option(Int),
    search: Option(String),
  )
}

pub fn member_state(
  config: MemberRouteConfig,
  mode: ViewMode,
) -> url_state.UrlState {
  base_state(config.selected_project_id)
  |> url_state.with_view(mode)
  |> url_state.with_capability_scope(config.capability_scope)
  |> url_state.with_type_filter(config.type_filter)
  |> url_state.with_capability_filter(config.capability_filter)
  |> url_state.with_search(config.search)
}

pub fn member_route(config: MemberRouteConfig, mode: ViewMode) -> router.Route {
  router.Member(member_section.Pool, member_state(config, mode))
}

pub fn current_member_route(config: MemberRouteConfig) -> router.Route {
  router.Member(
    current_member_section(config.member_section),
    member_state(config, config.view_mode),
  )
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

fn base_state(selected_project_id: Option(Int)) -> url_state.UrlState {
  case selected_project_id {
    Some(project_id) -> url_state.with_project(url_state.empty(), project_id)
    None -> url_state.empty()
  }
}

fn current_member_section(section: MemberSection) -> MemberSection {
  case section {
    member_section.MyBar -> member_section.Pool
    other -> other
  }
}

fn is_org_section(section: AdminSection) -> Bool {
  case section {
    permissions.Invites
    | permissions.OrgSettings
    | permissions.Projects
    | permissions.Assignments
    | permissions.ApiTokens
    | permissions.Metrics -> True
    _ -> False
  }
}
