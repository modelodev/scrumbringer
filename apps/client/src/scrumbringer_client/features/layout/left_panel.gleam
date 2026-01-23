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
import domain/view_mode.{type ViewMode, Cards, List, Pool}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons

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
    // Current view mode for active indicator (AC3)
    current_view_mode: Option(ViewMode),
    // Collapse state
    config_collapsed: Bool,
    org_collapsed: Bool,
    // Badge counts
    pending_invites_count: Int,
    projects_count: Int,
    // Event handlers
    on_project_change: fn(String) -> msg,
    on_new_task: msg,
    on_new_card: msg,
    // Navigation to work views (AC2)
    on_navigate_pool: msg,
    on_navigate_list: msg,
    on_navigate_cards: msg,
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
    on_navigate_org_metrics: msg,
    on_toggle_config: msg,
    on_toggle_org: msg,
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
      div(
        [attribute.class("nav-links")],
        [
          view_nav_link(
            config,
            Pool,
            "nav-pool",
            icons.Pool,
            i18n_text.Pool,
            config.on_navigate_pool,
          ),
          view_nav_link(
            config,
            List,
            "nav-list",
            icons.List,
            i18n_text.List,
            config.on_navigate_list,
          ),
          view_nav_link(
            config,
            Cards,
            "nav-cards",
            icons.Cards,
            i18n_text.MemberFichas,
            config.on_navigate_cards,
          ),
        ],
      ),
    ],
  )
}

/// Renders a navigation link with active indicator (AC3)
fn view_nav_link(
  config: LeftPanelConfig(msg),
  mode: ViewMode,
  testid: String,
  icon: icons.NavIcon,
  label_key: i18n_text.Text,
  on_click_msg: msg,
) -> Element(msg) {
  let is_active = config.current_view_mode == Some(mode)
  let active_class = case is_active {
    True -> " active"
    False -> ""
  }
  let active_indicator = case is_active {
    True -> span([attribute.class("active-indicator")], [text("●")])
    False -> element.none()
  }

  button(
    [
      attribute.class("nav-link" <> active_class),
      attribute.attribute("data-testid", testid),
      attribute.disabled(config.selected_project_id == None),
      event.on_click(on_click_msg),
    ],
    [
      icons.nav_icon(icon, icons.Small),
      span([attribute.class("nav-label")], [
        text(i18n.t(config.locale, label_key)),
      ]),
      active_indicator,
    ],
  )
}

// =============================================================================
// Configuration Section
// =============================================================================

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
          div(
            [attribute.class("section-items")],
            [
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-team"),
                  attribute.disabled(config.selected_project_id == None),
                  event.on_click(config.on_navigate_config_team),
                ],
                [
                  icons.nav_icon(icons.Team, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.Team)),
                  ]),
                ],
              ),
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-capabilities"),
                  attribute.disabled(config.selected_project_id == None),
                  event.on_click(config.on_navigate_config_capabilities),
                ],
                [
                  icons.nav_icon(icons.Crosshairs, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.Capabilities)),
                  ]),
                ],
              ),
              // Story 4.9 AC3: Separator - ORGANIZACIÓN DEL TRABAJO group
              view_nav_separator(),
              // Story 4.9: Cards Config nav item
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-cards-config"),
                  attribute.disabled(config.selected_project_id == None),
                  event.on_click(config.on_navigate_config_cards),
                ],
                [
                  icons.nav_icon(icons.Cards, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.CardsConfig)),
                  ]),
                ],
              ),
              // Story 4.9: Task Types nav item
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-task-types"),
                  attribute.disabled(config.selected_project_id == None),
                  event.on_click(config.on_navigate_config_task_types),
                ],
                [
                  icons.nav_icon(icons.TaskTypes, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.TaskTypes)),
                  ]),
                ],
              ),
              // Story 4.9 AC3: Separator - AUTOMATIZACIÓN group
              view_nav_separator(),
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-rules"),
                  attribute.disabled(config.selected_project_id == None),
                  event.on_click(config.on_navigate_config_rules),
                ],
                [
                  icons.nav_icon(icons.Automation, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.Rules)),
                  ]),
                ],
              ),
              // Story 4.9: Templates nav item
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-templates"),
                  attribute.disabled(config.selected_project_id == None),
                  event.on_click(config.on_navigate_config_templates),
                ],
                [
                  icons.nav_icon(icons.TaskTemplates, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.Templates)),
                  ]),
                ],
              ),
              // Story 4.9 AC3: Separator - RESULTADOS group
              view_nav_separator(),
              // AC31: Metrics link in Configuration section for PM/Admin
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-metrics"),
                  attribute.disabled(config.selected_project_id == None),
                  event.on_click(config.on_navigate_config_metrics),
                ],
                [
                  icons.nav_icon(icons.Metrics, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.AdminMetrics)),
                  ]),
                ],
              ),
            ],
          )
      },
    ],
  )
}

// =============================================================================
// Organization Section
// =============================================================================

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
          div(
            [attribute.class("section-items")],
            [
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-invites"),
                  event.on_click(config.on_navigate_org_invites),
                ],
                [
                  icons.nav_icon(icons.Invites, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.Invites)),
                  ]),
                  view_badge(config.pending_invites_count),
                ],
              ),
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-users"),
                  event.on_click(config.on_navigate_org_users),
                ],
                [
                  icons.nav_icon(icons.OrgUsers, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.OrgUsers)),
                  ]),
                ],
              ),
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-projects"),
                  event.on_click(config.on_navigate_org_projects),
                ],
                [
                  icons.nav_icon(icons.Projects, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.Projects)),
                  ]),
                  view_badge(config.projects_count),
                ],
              ),
              // AC32: Org Metrics link for Org Admin
              button(
                [
                  attribute.class("nav-link"),
                  attribute.attribute("data-testid", "nav-org-metrics"),
                  event.on_click(config.on_navigate_org_metrics),
                ],
                [
                  icons.nav_icon(icons.OrgMetrics, icons.Small),
                  span([attribute.class("nav-label")], [
                    text(i18n.t(config.locale, i18n_text.OrgMetrics)),
                  ]),
                ],
              ),
            ],
          )
      },
    ],
  )
}

/// Renders a badge with a count (only if count > 0)
fn view_badge(count: Int) -> Element(msg) {
  case count > 0 {
    True ->
      span(
        [attribute.class("badge")],
        [text(int_to_string(count))],
      )
    False -> element.none()
  }
}

// =============================================================================
// Helpers
// =============================================================================

import gleam/int

fn int_to_string(i: Int) -> String {
  int.to_string(i)
}
