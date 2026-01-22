//// Left Panel - Navigation panel for project and settings
////
//// Mission: Render the left navigation panel with project selector,
//// work actions, configuration links, and organization links.
////
//// Responsibilities:
//// - Project selector dropdown
//// - Work section (New Task, New Card buttons for PM/Admin)
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
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

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
    on_project_change: fn(String) -> msg,
    on_new_task: msg,
    on_new_card: msg,
    on_navigate_config_team: msg,
    on_navigate_config_catalog: msg,
    on_navigate_config_automation: msg,
    on_navigate_org_invites: msg,
    on_navigate_org_users: msg,
    on_navigate_org_projects: msg,
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
      // Work section - New Task/Card buttons for PM/Admin
      case config.is_pm || config.is_org_admin {
        True -> view_work_section(config)
        False -> element.none()
      },
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
    [attribute.class("panel-section")],
    [
      h4([attribute.class("section-title")], [
        text(i18n.t(config.locale, i18n_text.Work)),
      ]),
      button(
        [
          attribute.class("btn-action"),
          attribute.attribute("data-testid", "btn-new-task"),
          attribute.disabled(config.selected_project_id == None),
          event.on_click(config.on_new_task),
        ],
        [
          span([attribute.class("btn-icon-prefix")], [text("+")]),
          text(i18n.t(config.locale, i18n_text.NewTask)),
        ],
      ),
      button(
        [
          attribute.class("btn-action"),
          attribute.attribute("data-testid", "btn-new-card"),
          attribute.disabled(config.selected_project_id == None),
          event.on_click(config.on_new_card),
        ],
        [
          span([attribute.class("btn-icon-prefix")], [text("+")]),
          text(i18n.t(config.locale, i18n_text.NewCard)),
        ],
      ),
    ],
  )
}

// =============================================================================
// Configuration Section
// =============================================================================

fn view_config_section(config: LeftPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("panel-section collapsible"),
      attribute.attribute("data-testid", "section-config"),
    ],
    [
      h4([attribute.class("section-title")], [
        text(i18n.t(config.locale, i18n_text.Configuration)),
      ]),
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
            [text(i18n.t(config.locale, i18n_text.Team))],
          ),
          button(
            [
              attribute.class("nav-link"),
              attribute.attribute("data-testid", "nav-catalog"),
              attribute.disabled(config.selected_project_id == None),
              event.on_click(config.on_navigate_config_catalog),
            ],
            [text(i18n.t(config.locale, i18n_text.Catalog))],
          ),
          button(
            [
              attribute.class("nav-link"),
              attribute.attribute("data-testid", "nav-automation"),
              attribute.disabled(config.selected_project_id == None),
              event.on_click(config.on_navigate_config_automation),
            ],
            [text(i18n.t(config.locale, i18n_text.Automation))],
          ),
        ],
      ),
    ],
  )
}

// =============================================================================
// Organization Section
// =============================================================================

fn view_org_section(config: LeftPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("panel-section collapsible"),
      attribute.attribute("data-testid", "section-org"),
    ],
    [
      h4([attribute.class("section-title")], [
        text(i18n.t(config.locale, i18n_text.Organization)),
      ]),
      div(
        [attribute.class("section-items")],
        [
          button(
            [
              attribute.class("nav-link"),
              attribute.attribute("data-testid", "nav-invites"),
              event.on_click(config.on_navigate_org_invites),
            ],
            [text(i18n.t(config.locale, i18n_text.Invites))],
          ),
          button(
            [
              attribute.class("nav-link"),
              attribute.attribute("data-testid", "nav-users"),
              event.on_click(config.on_navigate_org_users),
            ],
            [text(i18n.t(config.locale, i18n_text.OrgUsers))],
          ),
          button(
            [
              attribute.class("nav-link"),
              attribute.attribute("data-testid", "nav-projects"),
              event.on_click(config.on_navigate_org_projects),
            ],
            [text(i18n.t(config.locale, i18n_text.Projects))],
          ),
        ],
      ),
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
