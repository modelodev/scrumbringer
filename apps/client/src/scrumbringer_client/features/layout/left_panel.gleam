//// Left Panel - Navigation panel for project and settings
////
//// Mission: Render the left navigation panel with project selector,
//// work actions, configuration links, and organization links.
////
//// Responsibilities:
//// - Project selector dropdown
//// - Work section (visible for ALL roles - AC1, AC7-9)
////   - New Task button: ALL members
////   - New Card button: PM/Admin only
////   - Navigation links: Pool, Lista, Tarjetas (ALL members)
//// - Configuration section (PM/Admin only)
//// - Organization section (Org Admin only)
//// - Unified active state indication across all nav items
////
//// Non-responsibilities:
//// - Layout structure (handled by ThreePanelLayout)
//// - Permission logic (receives as parameters)
//// - API calls (handled by parent)

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h4, option, select, span, text}
import lustre/event

import domain/project.{type Project}
import domain/user.{type User}
import domain/view_mode.{type ViewMode, Cards, List, People, Pool}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/ui/icons
import scrumbringer_client/url_state

// =============================================================================
// Types
// =============================================================================

/// Configuration for the left panel
pub type LeftPanelConfig(msg) {
  LeftPanelConfig(
    locale: Locale,
    user: Option(User),
    projects: List(Project),
    selected_project_id: Option(Int),
    is_pm: Bool,
    is_org_admin: Bool,
    // Current route for unified active indicator
    current_route: Option(router.Route),
    // Collapse state
    config_collapsed: Bool,
    org_collapsed: Bool,
    // Badge counts
    pending_invites_count: Int,
    projects_count: Int,
    users_count: Int,
    // Event handlers
    on_project_change: fn(String) -> msg,
    on_new_task: msg,
    on_new_card: msg,
    // Navigation to work views (AC2)
    on_navigate_pool: msg,
    on_navigate_list: msg,
    on_navigate_cards: msg,
    on_navigate_people: msg,
    // Config navigation
    on_navigate_config_team: msg,
    on_navigate_config_capabilities: msg,
    // Story 4.9: New config section navigation
    on_navigate_config_cards: msg,
    on_navigate_config_task_types: msg,
    on_navigate_config_templates: msg,
    on_navigate_config_rules: msg,
    on_navigate_config_metrics: msg,
    on_navigate_org_invites: msg,
    on_navigate_org_users: msg,
    on_navigate_org_projects: msg,
    on_navigate_org_assignments: msg,
    on_navigate_org_metrics: msg,
    on_toggle_config: msg,
    on_toggle_org: msg,
  )
}

/// Determines if a nav item is active based on current route
fn is_route_active(
  current_route: Option(router.Route),
  check_view_mode: Option(ViewMode),
  check_config_section: Option(permissions.AdminSection),
  check_org_section: Option(permissions.AdminSection),
) -> Bool {
  case current_route {
    None -> False
    Some(route) ->
      case route {
        // Work views: match by ViewMode
        router.Member(_, state) ->
          case check_view_mode, url_state.view_param(state) {
            Some(expected), Some(actual) -> expected == actual
            _, _ -> False
          }
        // Config sections: match by AdminSection
        router.Config(section, _) ->
          case check_config_section {
            Some(expected) -> expected == section
            None -> False
          }
        // Org sections: match by AdminSection
        router.Org(section) ->
          case check_org_section {
            Some(expected) -> expected == section
            None -> False
          }
        // Other routes don't match nav items
        _ -> False
      }
  }
}

/// Unified nav item renderer with active state
fn view_nav_item(
  locale: Locale,
  is_active: Bool,
  testid: String,
  icon: icons.NavIcon,
  label_key: i18n_text.Text,
  disabled: Bool,
  on_click_msg: msg,
  badge: Option(Int),
) -> Element(msg) {
  let active_class = case is_active {
    True -> " active"
    False -> ""
  }
  let active_indicator = case is_active {
    True -> span([attribute.class("active-indicator")], [text("●")])
    False -> element.none()
  }
  let badge_el = case badge {
    Some(count) if count > 0 ->
      span([attribute.class("badge")], [text(int_to_string(count))])
    _ -> element.none()
  }

  button(
    [
      attribute.class("nav-link" <> active_class),
      attribute.attribute("data-testid", testid),
      attribute.disabled(disabled),
      event.on_click(on_click_msg),
    ],
    [
      icons.nav_icon(icon, icons.Small),
      span([attribute.class("nav-label")], [text(i18n.t(locale, label_key))]),
      badge_el,
      active_indicator,
    ],
  )
}

// =============================================================================
// View Helpers
// =============================================================================

/// Visual separator for grouping nav items (Story 4.9 AC3)
fn view_nav_separator() -> Element(msg) {
  div(
    [
      attribute.class("nav-separator"),
      attribute.style("height", "1px"),
      attribute.style("background", "var(--sb-border)"),
      attribute.style("margin", "8px 12px"),
      attribute.style("opacity", "0.5"),
    ],
    [],
  )
}

// =============================================================================
// View
// =============================================================================

/// Renders the left panel with all sections
pub fn view(config: LeftPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("left-panel-content"),
    ],
    [
      // Project selector - always visible
      view_project_selector(config),
      // Work section - ALWAYS visible for ALL roles (AC1, AC7-9)
      // Contains: New Task (all), New Card (PM+), navigation links (all)
      view_work_section(config),
      // Configuration section - PM/Admin only
      case config.is_pm || config.is_org_admin {
        True -> view_config_section(config)
        False -> element.none()
      },
      // Organization section - Org Admin only
      case config.is_org_admin {
        True -> view_org_section(config)
        False -> element.none()
      },
    ],
  )
}

// =============================================================================
// Project Selector
// =============================================================================

fn view_project_selector(config: LeftPanelConfig(msg)) -> Element(msg) {
  let selected_value = case config.selected_project_id {
    Some(id) -> int_to_string(id)
    None -> ""
  }

  div(
    [
      attribute.class("project-selector-section"),
      attribute.attribute("data-testid", "project-selector"),
    ],
    [
      select(
        [
          attribute.class("project-selector-dropdown"),
          attribute.value(selected_value),
          event.on_input(config.on_project_change),
        ],
        [
          option(
            [attribute.value("")],
            i18n.t(config.locale, i18n_text.SelectProject),
          ),
          ..list.map(config.projects, fn(p) {
            option(
              [
                attribute.value(int_to_string(p.id)),
                attribute.selected(Some(p.id) == config.selected_project_id),
              ],
              p.name,
            )
          })
        ],
      ),
    ],
  )
}

// =============================================================================
// Work Section
// =============================================================================

fn view_work_section(config: LeftPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("panel-section"),
      attribute.attribute("data-testid", "section-work"),
    ],
    [
      h4([attribute.class("section-title")], [
        text(i18n.t(config.locale, i18n_text.Work)),
      ]),
      // New Task button - ALL roles (AC7)
      button(
        [
          attribute.class("btn-action btn-action-primary"),
          attribute.attribute("data-testid", "btn-new-task"),
          attribute.disabled(config.selected_project_id == None),
          event.on_click(config.on_new_task),
        ],
        [
          span([attribute.class("btn-icon-prefix")], [text("+")]),
          text(i18n.t(config.locale, i18n_text.NewTask)),
        ],
      ),
      // New Card button - PM/Admin only (AC8, AC9)
      case config.is_pm || config.is_org_admin {
        True ->
          button(
            [
              attribute.class("btn-action btn-action-primary"),
              attribute.attribute("data-testid", "btn-new-card"),
              attribute.disabled(config.selected_project_id == None),
              event.on_click(config.on_new_card),
            ],
            [
              span([attribute.class("btn-icon-prefix")], [text("+")]),
              text(i18n.t(config.locale, i18n_text.NewCard)),
            ],
          )
        False -> element.none()
      },
      // Navigation links - ALL roles (AC2)
      div([attribute.class("nav-links")], [
        view_work_nav_link(
          config,
          Pool,
          "nav-pool",
          icons.Pool,
          i18n_text.Pool,
          config.on_navigate_pool,
        ),
        view_work_nav_link(
          config,
          List,
          "nav-list",
          icons.List,
          i18n_text.List,
          config.on_navigate_list,
        ),
        view_work_nav_link(
          config,
          Cards,
          "nav-cards",
          icons.Cards,
          i18n_text.MemberFichas,
          config.on_navigate_cards,
        ),
        view_work_nav_link(
          config,
          People,
          "nav-people",
          icons.Team,
          i18n_text.People,
          config.on_navigate_people,
        ),
      ]),
    ],
  )
}

/// Renders a work section navigation link (Pool/List/Cards)
fn view_work_nav_link(
  config: LeftPanelConfig(msg),
  mode: ViewMode,
  testid: String,
  icon: icons.NavIcon,
  label_key: i18n_text.Text,
  on_click_msg: msg,
) -> Element(msg) {
  let is_active = is_route_active(config.current_route, Some(mode), None, None)
  view_nav_item(
    config.locale,
    is_active,
    testid,
    icon,
    label_key,
    config.selected_project_id == None,
    on_click_msg,
    None,
  )
}

// =============================================================================
// Configuration Section
// =============================================================================

/// Renders a config section navigation link
fn view_config_nav_link(
  config: LeftPanelConfig(msg),
  section: permissions.AdminSection,
  testid: String,
  icon: icons.NavIcon,
  label_key: i18n_text.Text,
  on_click_msg: msg,
) -> Element(msg) {
  let is_active =
    is_route_active(config.current_route, None, Some(section), None)
  view_nav_item(
    config.locale,
    is_active,
    testid,
    icon,
    label_key,
    config.selected_project_id == None,
    on_click_msg,
    None,
  )
}

fn view_config_section(config: LeftPanelConfig(msg)) -> Element(msg) {
  let collapsed_class = case config.config_collapsed {
    True -> " collapsed"
    False -> ""
  }
  let toggle_icon = case config.config_collapsed {
    True -> "▸"
    False -> "▾"
  }

  div(
    [
      attribute.class("panel-section collapsible" <> collapsed_class),
      attribute.attribute("data-testid", "section-config"),
    ],
    [
      button(
        [
          attribute.class("section-header"),
          event.on_click(config.on_toggle_config),
        ],
        [
          span([attribute.class("section-toggle")], [text(toggle_icon)]),
          h4([attribute.class("section-title")], [
            text(i18n.t(config.locale, i18n_text.Configuration)),
          ]),
        ],
      ),
      case config.config_collapsed {
        True -> element.none()
        False ->
          div([attribute.class("section-items")], [
            view_config_nav_link(
              config,
              permissions.Members,
              "nav-team",
              icons.Team,
              i18n_text.Team,
              config.on_navigate_config_team,
            ),
            view_config_nav_link(
              config,
              permissions.Capabilities,
              "nav-capabilities",
              icons.Crosshairs,
              i18n_text.Capabilities,
              config.on_navigate_config_capabilities,
            ),
            // Story 4.9 AC3: Separator - ORGANIZACIÓN DEL TRABAJO group
            view_nav_separator(),
            view_config_nav_link(
              config,
              permissions.Cards,
              "nav-cards-config",
              icons.Cards,
              i18n_text.CardsConfig,
              config.on_navigate_config_cards,
            ),
            view_config_nav_link(
              config,
              permissions.TaskTypes,
              "nav-task-types",
              icons.TaskTypes,
              i18n_text.TaskTypes,
              config.on_navigate_config_task_types,
            ),
            // Story 4.9 AC3: Separator - AUTOMATIZACIÓN group
            view_nav_separator(),
            view_config_nav_link(
              config,
              permissions.Workflows,
              "nav-rules",
              icons.Automation,
              i18n_text.AdminWorkflows,
              config.on_navigate_config_rules,
            ),
            view_config_nav_link(
              config,
              permissions.TaskTemplates,
              "nav-templates",
              icons.TaskTemplates,
              i18n_text.Templates,
              config.on_navigate_config_templates,
            ),
            // Story 4.9 AC3: Separator - RESULTADOS group
            view_nav_separator(),
            view_config_nav_link(
              config,
              permissions.RuleMetrics,
              "nav-metrics",
              icons.Metrics,
              i18n_text.AdminMetrics,
              config.on_navigate_config_metrics,
            ),
          ])
      },
    ],
  )
}

// =============================================================================
// Organization Section
// =============================================================================

/// Renders an org section navigation link
fn view_org_nav_link(
  config: LeftPanelConfig(msg),
  section: permissions.AdminSection,
  testid: String,
  icon: icons.NavIcon,
  label_key: i18n_text.Text,
  on_click_msg: msg,
  badge: Option(Int),
) -> Element(msg) {
  let is_active =
    is_route_active(config.current_route, None, None, Some(section))
  view_nav_item(
    config.locale,
    is_active,
    testid,
    icon,
    label_key,
    False,
    // Org section items are never disabled
    on_click_msg,
    badge,
  )
}

fn view_org_section(config: LeftPanelConfig(msg)) -> Element(msg) {
  let collapsed_class = case config.org_collapsed {
    True -> " collapsed"
    False -> ""
  }
  let toggle_icon = case config.org_collapsed {
    True -> "▸"
    False -> "▾"
  }

  div(
    [
      attribute.class("panel-section collapsible" <> collapsed_class),
      attribute.attribute("data-testid", "section-org"),
    ],
    [
      button(
        [
          attribute.class("section-header"),
          event.on_click(config.on_toggle_org),
        ],
        [
          span([attribute.class("section-toggle")], [text(toggle_icon)]),
          h4([attribute.class("section-title")], [
            text(i18n.t(config.locale, i18n_text.Organization)),
          ]),
        ],
      ),
      case config.org_collapsed {
        True -> element.none()
        False ->
          div([attribute.class("section-items")], [
            view_org_nav_link(
              config,
              permissions.Invites,
              "nav-invites",
              icons.Invites,
              i18n_text.Invites,
              config.on_navigate_org_invites,
              Some(config.pending_invites_count),
            ),
            view_org_nav_link(
              config,
              permissions.OrgSettings,
              "nav-users",
              icons.OrgUsers,
              i18n_text.OrgUsers,
              config.on_navigate_org_users,
              Some(config.users_count),
            ),
            view_org_nav_link(
              config,
              permissions.Projects,
              "nav-projects",
              icons.Projects,
              i18n_text.Projects,
              config.on_navigate_org_projects,
              Some(config.projects_count),
            ),
            view_org_nav_link(
              config,
              permissions.Assignments,
              "nav-assignments",
              icons.Team,
              i18n_text.Assignments,
              config.on_navigate_org_assignments,
              None,
            ),
            view_org_nav_link(
              config,
              permissions.Metrics,
              "nav-org-metrics",
              icons.OrgMetrics,
              i18n_text.OrgMetrics,
              config.on_navigate_org_metrics,
              None,
            ),
          ])
      },
    ],
  )
}

// =============================================================================
// Helpers
// =============================================================================

import gleam/int

fn int_to_string(i: Int) -> String {
  int.to_string(i)
}
