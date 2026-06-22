//// Unified automations admin console.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{a, div, text}

import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

pub type Mode {
  Engines
  Templates
  Executions
}

pub type Config(msg) {
  Config(
    selected_project_id: opt.Option(Int),
    mode: Mode,
    engines_view: Element(msg),
    templates_view: Element(msg),
    executions_view: Element(msg),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("section automations-console"),
      test_id("automations-surface"),
    ],
    [
      section_header.view(icons.Automation, "Automations"),
      view_modes(config),
      div([attribute.class("automations-console__content")], [
        case config.mode {
          Engines -> config.engines_view
          Templates -> config.templates_view
          Executions -> config.executions_view
        },
      ]),
    ],
  )
}

fn view_modes(config: Config(msg)) -> Element(msg) {
  div([attribute.class("automations-console__modes")], [
    view_mode_link(
      config,
      Engines,
      permissions.Workflows,
      "automations-mode-engines",
      "Motors",
    ),
    view_mode_link(
      config,
      Templates,
      permissions.TaskTemplates,
      "automations-mode-templates",
      "Templates",
    ),
    view_mode_link(
      config,
      Executions,
      permissions.RuleMetrics,
      "automations-mode-executions",
      "Executions",
    ),
  ])
}

fn view_mode_link(
  config: Config(msg),
  mode: Mode,
  section: permissions.AdminSection,
  id: String,
  label: String,
) -> Element(msg) {
  a(
    [
      attribute.href(
        router.format(router.Config(section, config.selected_project_id)),
      ),
      attribute.class(mode_class(config.mode, mode)),
      test_id(id),
    ],
    [text(label)],
  )
}

fn mode_class(active: Mode, mode: Mode) -> String {
  let base = "automations-console__mode"
  case active == mode {
    True -> base <> " is-active"
    False -> base
  }
}

fn test_id(value: String) -> attribute.Attribute(msg) {
  attribute.attribute("data-testid", value)
}
