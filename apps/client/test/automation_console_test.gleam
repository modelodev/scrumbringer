import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, text}
import support/render_assertions

import scrumbringer_client/automation_deep_link
import scrumbringer_client/features/automations/console as automations_console
import scrumbringer_client/i18n/locale

fn render(mode: automations_console.Mode) -> String {
  render_with_locale(mode, locale.En)
}

fn render_with_locale(
  mode: automations_console.Mode,
  current_locale: locale.Locale,
) -> String {
  automations_console.Config(
    locale: current_locale,
    selected_project_id: Some(7),
    mode: mode,
    selected_entity: None,
    active_engines_count: 2,
    rules_count: 4,
    templates_count: 3,
    created_tasks_count: 12,
    primary_action: Some(primary_action()),
    engines_view: div([], [text("engines body")]),
    templates_view: div([], [text("templates body")]),
    executions_view: div([], [text("executions body")]),
  )
  |> automations_console.view
  |> render_assertions.html
}

pub fn automations_console_uses_work_surface_contract_test() {
  let html = render(automations_console.Engines)

  render_assertions.contains(html, "data-testid=\"automations-surface\"")
  render_assertions.contains(html, "work-surface automations-console")
  render_assertions.contains(html, "data-testid=\"automations-surface-header\"")
  render_assertions.contains(html, "Automations")
  render_assertions.contains(
    html,
    "Create work automatically in the Pool without assigning it to anyone.",
  )
  render_assertions.contains(html, "active engines")
  render_assertions.contains(html, "rules")
  render_assertions.contains(html, "templates")
  render_assertions.contains(html, "created tasks")
  render_assertions.contains(html, ">2<")
  render_assertions.contains(html, ">4<")
  render_assertions.contains(html, ">3<")
  render_assertions.contains(html, ">12<")
  render_assertions.contains(html, "data-testid=\"automation-create-engine\"")
  render_assertions.contains(html, "Create engine")
  render_assertions.contains(html, "engines body")
}

pub fn automations_console_renders_internal_modes_as_tabs_test() {
  let html = render(automations_console.Executions)

  render_assertions.contains(html, "role=\"tablist\"")
  render_assertions.contains(html, "data-testid=\"automations-mode-engines\"")
  render_assertions.contains(html, "data-testid=\"automations-mode-templates\"")
  render_assertions.contains(
    html,
    "data-testid=\"automations-mode-executions\"",
  )
  render_assertions.contains(html, "href=\"/config/workflows?project=7\"")
  render_assertions.contains(
    html,
    "href=\"/config/workflows?project=7&amp;mode=templates\"",
  )
  render_assertions.contains(
    html,
    "href=\"/config/workflows?project=7&amp;mode=executions\"",
  )
  render_assertions.contains(html, ">Engines<")
  render_assertions.contains(html, ">Templates<")
  render_assertions.contains(html, ">Executions<")
  render_assertions.contains(html, "aria-selected=\"true\"")
  render_assertions.contains(html, "executions body")
  render_assertions.not_contains(html, "engines body")
  render_assertions.not_contains(html, "templates body")
  render_assertions.not_contains(html, "href=\"/config/templates")
  render_assertions.not_contains(html, "href=\"/config/rule-metrics")
}

pub fn automations_console_renders_selected_entity_context_test() {
  let html =
    automations_console.Config(
      locale: locale.En,
      selected_project_id: Some(7),
      mode: automations_console.Templates,
      selected_entity: Some(automation_deep_link.SelectedTemplate(12)),
      active_engines_count: 2,
      rules_count: 4,
      templates_count: 3,
      created_tasks_count: 12,
      primary_action: None,
      engines_view: div([], [text("engines body")]),
      templates_view: div([], [text("templates body")]),
      executions_view: div([], [text("executions body")]),
    )
    |> automations_console.view
    |> render_assertions.html

  render_assertions.contains(html, "data-testid=\"automation-selected-entity\"")
  render_assertions.contains(html, "Template #12 selected")
  render_assertions.not_contains(html, "Plantilla #12 seleccionada")
}

pub fn automations_console_localizes_selected_entity_context_to_spanish_test() {
  let html =
    automations_console.Config(
      locale: locale.Es,
      selected_project_id: Some(7),
      mode: automations_console.Engines,
      selected_entity: Some(automation_deep_link.SelectedRule(8, Some(3))),
      active_engines_count: 2,
      rules_count: 4,
      templates_count: 3,
      created_tasks_count: 12,
      primary_action: None,
      engines_view: div([], [text("engines body")]),
      templates_view: div([], [text("templates body")]),
      executions_view: div([], [text("executions body")]),
    )
    |> automations_console.view
    |> render_assertions.html

  render_assertions.contains(html, "Automatizaciones")
  render_assertions.contains(html, "Crea trabajo automático en el Pool")
  render_assertions.contains(html, "Regla #8 seleccionada en motor #3")
  render_assertions.contains(html, ">Motores<")
  render_assertions.contains(html, ">Plantillas<")
  render_assertions.contains(html, ">Ejecuciones<")
  render_assertions.not_contains(html, "Rule #8 selected")
}

fn primary_action() -> Element(msg) {
  button([attribute.attribute("data-testid", "automation-create-engine")], [
    text("Create engine"),
  ])
}
