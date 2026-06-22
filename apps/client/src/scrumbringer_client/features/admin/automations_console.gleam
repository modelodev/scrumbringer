//// Unified automations admin console.

import gleam/int
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{a, div, text}

import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/ui/tone

pub type Mode {
  Engines
  Templates
  Executions
}

pub type Config(msg) {
  Config(
    selected_project_id: opt.Option(Int),
    mode: Mode,
    active_engines_count: Int,
    rules_count: Int,
    templates_count: Int,
    created_tasks_count: Int,
    engines_view: Element(msg),
    templates_view: Element(msg),
    executions_view: Element(msg),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let header =
    work_surface.HeaderConfig(
      title: "Automatizaciones",
      purpose: "Crea trabajo automatico en el Pool sin asignarlo a nadie.",
      summary: summary(config),
      actions: [],
      extra_class: opt.Some("automations-console__header"),
      testid: opt.Some("automations-surface-header"),
    )
    |> work_surface.header

  work_surface.new_surface(header)
  |> work_surface.with_filters(view_modes(config))
  |> work_surface.with_content(
    div([attribute.class("automations-console__content")], [
      case config.mode {
        Engines -> config.engines_view
        Templates -> config.templates_view
        Executions -> config.executions_view
      },
    ]),
  )
  |> work_surface.surface_with_class("automations-console")
  |> work_surface.surface_with_testid("automations-surface")
  |> work_surface.surface
}

fn summary(config: Config(msg)) -> List(work_surface.SummaryChip) {
  [
    work_surface.summary_chip(
      "motores activos",
      int_to_string(config.active_engines_count),
      tone.Success,
    ),
    work_surface.summary_chip(
      "reglas",
      int_to_string(config.rules_count),
      tone.Primary,
    ),
    work_surface.summary_chip(
      "plantillas",
      int_to_string(config.templates_count),
      tone.Info,
    ),
    work_surface.summary_chip(
      "tasks creadas",
      int_to_string(config.created_tasks_count),
      tone.Warning,
    ),
  ]
}

fn view_modes(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("automations-console__modes"),
      attribute.attribute("role", "tablist"),
      attribute.attribute("aria-label", "Modo de automatizaciones"),
    ],
    [
      view_mode_link(
        config,
        Engines,
        permissions.Workflows,
        "automations-mode-engines",
        "Motores",
      ),
      view_mode_link(
        config,
        Templates,
        permissions.TaskTemplates,
        "automations-mode-templates",
        "Plantillas",
      ),
      view_mode_link(
        config,
        Executions,
        permissions.RuleMetrics,
        "automations-mode-executions",
        "Ejecuciones",
      ),
    ],
  )
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
      attribute.attribute("role", "tab"),
      attribute.attribute("aria-selected", bool_to_string(config.mode == mode)),
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

fn int_to_string(value: Int) -> String {
  int.to_string(value)
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
