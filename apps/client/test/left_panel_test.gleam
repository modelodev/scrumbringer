import gleam/list
import gleam/option as opt
import gleam/string
import gleeunit/should
import lustre/element

import domain/view_mode as view_mode_module
import scrumbringer_client/features/layout/left_panel
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/url_state

fn base_config(
  current_route: opt.Option(router.Route),
) -> left_panel.LeftPanelConfig(String) {
  left_panel.LeftPanelConfig(
    locale: i18n_locale.En,
    user: opt.None,
    projects: [],
    selected_project_id: opt.Some(1),
    is_pm: False,
    is_org_admin: False,
    current_route: current_route,
    config_collapsed: True,
    org_collapsed: True,
    pending_invites_count: 0,
    projects_count: 0,
    users_count: 0,
    on_project_change: fn(_value) { "msg" },
    on_new_task: "msg",
    on_new_card: "msg",
    on_navigate_pool: "msg",
    on_navigate_cards: "msg",
    on_navigate_people: "msg",
    on_navigate_milestones: "msg",
    on_navigate_config_team: "msg",
    on_navigate_config_capabilities: "msg",
    on_navigate_config_cards: "msg",
    on_navigate_config_task_types: "msg",
    on_navigate_config_templates: "msg",
    on_navigate_config_rules: "msg",
    on_navigate_config_metrics: "msg",
    on_navigate_org_invites: "msg",
    on_navigate_org_users: "msg",
    on_navigate_org_projects: "msg",
    on_navigate_org_assignments: "msg",
    on_navigate_org_metrics: "msg",
    on_toggle_config: "msg",
    on_toggle_org: "msg",
  )
}

/// Helper to create a Member route with a view mode
fn member_route(mode: view_mode_module.ViewMode) -> router.Route {
  let state =
    url_state.empty()
    |> url_state.with_project(1)
    |> url_state.with_view(mode)
  router.Member(member_section.Pool, state)
}

/// Helper to create a Config route with an admin section
fn config_route(section: permissions.AdminSection) -> router.Route {
  router.Config(section, opt.Some(1))
}

/// Helper to create an Org route with an admin section
fn org_route(section: permissions.AdminSection) -> router.Route {
  router.Org(section)
}

pub fn left_panel_active_nav_has_active_class_test() {
  let rendered =
    left_panel.view(base_config(opt.Some(member_route(view_mode_module.Pool))))
  let html = element.to_document_string(rendered)

  string.contains(html, "nav-link active") |> should.be_true
}

pub fn left_panel_all_view_modes_can_be_active_test() {
  [
    view_mode_module.Pool,
    view_mode_module.Cards,
    view_mode_module.People,
    view_mode_module.Milestones,
  ]
  |> list.each(fn(mode) {
    let rendered = left_panel.view(base_config(opt.Some(member_route(mode))))
    let html = element.to_document_string(rendered)
    string.contains(html, "nav-link active") |> should.be_true
  })
}

pub fn left_panel_config_section_active_test() {
  // Config section needs is_pm or is_org_admin to be visible
  let config =
    left_panel.LeftPanelConfig(
      ..base_config(opt.Some(config_route(permissions.Members))),
      is_pm: True,
      config_collapsed: False,
    )
  let rendered = left_panel.view(config)
  let html = element.to_document_string(rendered)

  // Should have active class on the Team nav item
  string.contains(html, "nav-link active") |> should.be_true
}

pub fn left_panel_org_section_active_test() {
  // Org section needs is_org_admin to be visible
  let config =
    left_panel.LeftPanelConfig(
      ..base_config(opt.Some(org_route(permissions.Invites))),
      is_org_admin: True,
      org_collapsed: False,
    )
  let rendered = left_panel.view(config)
  let html = element.to_document_string(rendered)

  // Should have active class on the Invites nav item
  string.contains(html, "nav-link active") |> should.be_true
}
