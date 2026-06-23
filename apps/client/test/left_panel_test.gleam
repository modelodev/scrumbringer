import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string
import lustre/element

import domain/view_mode as view_mode_module
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/layout/left_panel
import scrumbringer_client/i18n/locale as i18n_locale
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/url_state

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

fn assert_true(value: Bool) {
  let assert True = value
}

fn assert_equal(actual: a, expected: a) {
  let assert True = actual == expected
}

fn count_occurrences(haystack: String, needle: String) -> Int {
  string.split(haystack, needle)
  |> list.length
  |> fn(parts) { parts - 1 }
}

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
    depth_names: [
      scope_view.DepthName(1, "Epic", "Epics"),
      scope_view.DepthName(2, "Story", "Stories"),
    ],
    on_project_change: fn(_value) { "msg" },
    on_new_task: "msg",
    on_new_card: "msg",
    on_navigate_pool: "msg",
    on_navigate_kanban: "msg",
    on_navigate_cards: "msg",
    on_navigate_depth: fn(depth) { "depth:" <> int.to_string(depth) },
    on_navigate_capabilities: "msg",
    on_navigate_people: "msg",
    on_navigate_config_team: "msg",
    on_navigate_config_capabilities: "msg",
    on_navigate_config_cards: "msg",
    on_navigate_config_task_types: "msg",
    on_navigate_config_rules: "msg",
    on_navigate_org_invites: "msg",
    on_navigate_org_users: "msg",
    on_navigate_org_projects: "msg",
    on_navigate_org_assignments: "msg",
    on_navigate_org_api_tokens: "msg",
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
  router.Member(state)
}

fn member_kanban_route() -> router.Route {
  let state =
    url_state.empty()
    |> url_state.with_project(1)
    |> url_state.with_view(view_mode_module.Cards)
    |> url_state.with_plan_mode(url_state.PlanKanbanParam)
  router.Member(state)
}

fn member_depth_route(depth: Int) -> router.Route {
  let state =
    url_state.empty()
    |> url_state.with_project(1)
    |> url_state.with_view(view_mode_module.Cards)
    |> url_state.with_card_depth(opt.Some(depth))
  router.Member(state)
}

/// Helper to create a Config route with an admin section
fn config_route(section: permissions.AdminSection) -> router.Route {
  router.Config(section, opt.Some(1))
}

/// Helper to create an Org route with an admin section
fn org_route(section: permissions.AdminSection) -> router.Route {
  router.Org(section)
}

fn appears_before(html: String, first: String, second: String) -> Bool {
  case string.split_once(html, first) {
    Ok(#(_, after_first)) -> string.contains(after_first, second)
    Error(_) -> False
  }
}

pub fn left_panel_active_nav_has_active_class_test() {
  let rendered =
    left_panel.view(base_config(opt.Some(member_route(view_mode_module.Pool))))
  let html = element.to_document_string(rendered)

  assert_contains(html, "nav-link active")
}

pub fn left_panel_all_view_modes_can_be_active_test() {
  [
    view_mode_module.Pool,
    view_mode_module.Cards,
    view_mode_module.Capabilities,
    view_mode_module.People,
  ]
  |> list.each(fn(mode) {
    let rendered = left_panel.view(base_config(opt.Some(member_route(mode))))
    let html = element.to_document_string(rendered)
    assert_contains(html, "nav-link active")
  })
}

pub fn left_panel_kanban_route_can_be_active_test() {
  let rendered = left_panel.view(base_config(opt.Some(member_kanban_route())))
  let html = element.to_document_string(rendered)

  assert_contains(html, "class=\"nav-link active\" data-testid=\"nav-kanban\"")
  assert_not_contains(
    html,
    "class=\"nav-link active\" data-testid=\"nav-cards\"",
  )
  count_occurrences(html, "class=\"nav-link active\"") |> assert_equal(1)
  count_occurrences(html, "aria-current=\"page\"") |> assert_equal(1)
}

pub fn left_panel_does_not_render_legacy_hierarchy_nav_test() {
  let rendered =
    left_panel.view(base_config(opt.Some(member_route(view_mode_module.Pool))))
  let html = element.to_document_string(rendered)

  assert_not_contains(html, "nav-hierarchies")
}

pub fn left_panel_create_actions_are_global_shortcuts_test() {
  let config =
    left_panel.LeftPanelConfig(
      ..base_config(opt.Some(member_route(view_mode_module.Pool))),
      is_pm: True,
    )
  let html = left_panel.view(config) |> element.to_document_string

  assert_contains(html, "btn-action btn-action-shortcut")
  assert_contains(html, "data-testid=\"btn-new-task\"")
  assert_contains(html, "data-testid=\"btn-new-card\"")
  assert_not_contains(html, "btn-action btn-action-primary")
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
  assert_contains(html, "nav-link active")
}

pub fn left_panel_config_has_single_automations_entry_test() {
  let config =
    left_panel.LeftPanelConfig(
      ..base_config(opt.Some(config_route(permissions.Workflows))),
      is_pm: True,
      config_collapsed: False,
    )
  let html = left_panel.view(config) |> element.to_document_string

  assert_contains(html, "data-testid=\"nav-automations\"")
  assert_contains(html, "<span class=\"nav-label\">Automations</span>")
  assert_not_contains(html, "data-testid=\"nav-templates\"")
  assert_not_contains(html, "data-testid=\"nav-rule-metrics\"")
  assert_not_contains(html, "<span class=\"nav-label\">Templates</span>")
  assert_not_contains(html, "<span class=\"nav-label\">Executions</span>")
}

pub fn left_panel_automation_entry_active_for_all_console_modes_test() {
  [
    permissions.Workflows,
    permissions.TaskTemplates,
    permissions.RuleMetrics,
  ]
  |> list.each(fn(section) {
    let config =
      left_panel.LeftPanelConfig(
        ..base_config(opt.Some(config_route(section))),
        is_pm: True,
        config_collapsed: False,
      )
    let html = left_panel.view(config) |> element.to_document_string

    assert_contains(
      html,
      "class=\"nav-link active\" data-testid=\"nav-automations\"",
    )
    count_occurrences(html, "class=\"nav-link active\"") |> assert_equal(1)
  })
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
  assert_contains(html, "nav-link active")
}

pub fn left_panel_collapsed_config_items_are_not_rendered_test() {
  let config =
    left_panel.LeftPanelConfig(
      ..base_config(opt.Some(config_route(permissions.Members))),
      is_pm: True,
      config_collapsed: True,
    )
  let html = left_panel.view(config) |> element.to_document_string

  assert_contains(html, "data-testid=\"section-config\"")
  assert_not_contains(html, "data-testid=\"nav-team\"")
}

pub fn left_panel_collapsed_org_items_are_not_rendered_test() {
  let config =
    left_panel.LeftPanelConfig(
      ..base_config(opt.Some(org_route(permissions.Projects))),
      is_org_admin: True,
      org_collapsed: True,
    )
  let html = left_panel.view(config) |> element.to_document_string

  assert_contains(html, "data-testid=\"section-org\"")
  assert_not_contains(html, "data-testid=\"nav-projects\"")
}

pub fn left_panel_work_nav_order_is_pool_kanban_plan_capabilities_people_en_test() {
  let html =
    left_panel.view(base_config(opt.Some(member_route(view_mode_module.Pool))))
    |> element.to_document_string

  appears_before(html, "data-testid=\"nav-pool\"", "data-testid=\"nav-kanban\"")
  |> assert_true
  appears_before(
    html,
    "data-testid=\"nav-kanban\"",
    "data-testid=\"nav-cards\"",
  )
  |> assert_true
  appears_before(
    html,
    "data-testid=\"nav-cards\"",
    "data-testid=\"nav-capabilities-board\"",
  )
  |> assert_true
  appears_before(
    html,
    "data-testid=\"nav-capabilities-board\"",
    "data-testid=\"nav-people\"",
  )
  |> assert_true
  assert_contains(html, "<span class=\"nav-label\">Pool</span>")
  assert_contains(html, "<span class=\"nav-label\">Kanban</span>")
  assert_contains(html, "<span class=\"nav-label\">Plan</span>")
  assert_contains(html, "<span class=\"nav-label\">Capabilities</span>")
  assert_contains(html, "<span class=\"nav-label\">People</span>")
  assert_not_contains(html, ">List<")
}

pub fn left_sidebar_does_not_render_depth_names_from_project_config_test() {
  let html =
    left_panel.view(base_config(opt.Some(member_route(view_mode_module.Cards))))
    |> element.to_document_string

  assert_not_contains(html, "data-testid=\"nav-depth-1\"")
  assert_not_contains(html, "<span class=\"nav-label\">Epics</span>")
  assert_not_contains(html, "data-testid=\"nav-depth-2\"")
  assert_not_contains(html, "<span class=\"nav-label\">Stories</span>")
  assert_not_contains(html, "<span class=\"nav-label\">Hierarchies</span>")
}

pub fn left_sidebar_cards_route_does_not_activate_depth_links_test() {
  let html =
    left_panel.view(base_config(opt.Some(member_route(view_mode_module.Cards))))
    |> element.to_document_string

  assert_contains(html, "class=\"nav-link active\" data-testid=\"nav-cards\"")
  count_occurrences(html, "class=\"nav-link active\"") |> assert_equal(1)
  count_occurrences(html, "aria-current=\"page\"") |> assert_equal(1)
  assert_not_contains(
    html,
    "class=\"nav-link active\" data-testid=\"nav-depth-1\"",
  )
  assert_not_contains(
    html,
    "class=\"nav-link active\" data-testid=\"nav-depth-2\"",
  )
}

pub fn left_sidebar_kanban_route_does_not_activate_plan_test() {
  let html =
    left_panel.view(base_config(opt.Some(member_kanban_route())))
    |> element.to_document_string

  assert_contains(html, "class=\"nav-link active\" data-testid=\"nav-kanban\"")
  assert_not_contains(
    html,
    "class=\"nav-link active\" data-testid=\"nav-cards\"",
  )
  count_occurrences(html, "class=\"nav-link active\"") |> assert_equal(1)
  count_occurrences(html, "aria-current=\"page\"") |> assert_equal(1)
}

pub fn left_sidebar_depth_route_keeps_plan_as_only_active_nav_test() {
  let html =
    left_panel.view(base_config(opt.Some(member_depth_route(2))))
    |> element.to_document_string

  assert_not_contains(html, "data-testid=\"nav-depth-2\"")
  assert_contains(html, "class=\"nav-link active\" data-testid=\"nav-cards\"")
  count_occurrences(html, "class=\"nav-link active\"") |> assert_equal(1)
  count_occurrences(html, "aria-current=\"page\"") |> assert_equal(1)
}

pub fn left_panel_work_nav_order_is_pool_kanban_plan_capacidades_personas_es_test() {
  let config =
    left_panel.LeftPanelConfig(
      ..base_config(opt.Some(member_route(view_mode_module.Pool))),
      locale: i18n_locale.Es,
    )

  let html = left_panel.view(config) |> element.to_document_string

  appears_before(html, "data-testid=\"nav-pool\"", "data-testid=\"nav-kanban\"")
  |> assert_true
  appears_before(
    html,
    "data-testid=\"nav-kanban\"",
    "data-testid=\"nav-cards\"",
  )
  |> assert_true
  appears_before(
    html,
    "data-testid=\"nav-cards\"",
    "data-testid=\"nav-capabilities-board\"",
  )
  |> assert_true
  appears_before(
    html,
    "data-testid=\"nav-capabilities-board\"",
    "data-testid=\"nav-people\"",
  )
  |> assert_true
  assert_contains(html, "<span class=\"nav-label\">Pool</span>")
  assert_contains(html, "<span class=\"nav-label\">Kanban</span>")
  assert_contains(html, "<span class=\"nav-label\">Plan</span>")
  assert_contains(html, "<span class=\"nav-label\">Capacidades</span>")
  assert_contains(html, "<span class=\"nav-label\">Personas</span>")
  assert_not_contains(html, ">Lista<")
}
