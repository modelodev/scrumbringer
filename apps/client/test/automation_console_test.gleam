import gleam/option.{None, Some}
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html.{button, div, text}

import scrumbringer_client/automation_deep_link
import scrumbringer_client/features/automations/console as automations_console
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

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
  |> element.to_document_string
}

pub fn automations_console_uses_work_surface_contract_test() {
  let html = render(automations_console.Engines)

  assert_contains(html, "data-testid=\"automations-surface\"")
  assert_contains(html, "work-surface automations-console")
  assert_contains(html, "data-testid=\"automations-surface-header\"")
  assert_contains(html, "Automations")
  assert_contains(
    html,
    "Create work automatically in the Pool without assigning it to anyone.",
  )
  assert_contains(html, "active engines")
  assert_contains(html, "rules")
  assert_contains(html, "templates")
  assert_contains(html, "created tasks")
  assert_contains(html, ">2<")
  assert_contains(html, ">4<")
  assert_contains(html, ">3<")
  assert_contains(html, ">12<")
  assert_contains(html, "data-testid=\"automation-create-engine\"")
  assert_contains(html, "Create engine")
  assert_contains(html, "engines body")
}

pub fn automations_console_renders_internal_modes_as_tabs_test() {
  let html = render(automations_console.Executions)

  assert_contains(html, "role=\"tablist\"")
  assert_contains(html, "data-testid=\"automations-mode-engines\"")
  assert_contains(html, "data-testid=\"automations-mode-templates\"")
  assert_contains(html, "data-testid=\"automations-mode-executions\"")
  assert_contains(html, "href=\"/config/workflows?project=7\"")
  assert_contains(
    html,
    "href=\"/config/workflows?project=7&amp;mode=templates\"",
  )
  assert_contains(
    html,
    "href=\"/config/workflows?project=7&amp;mode=executions\"",
  )
  assert_contains(html, ">Engines<")
  assert_contains(html, ">Templates<")
  assert_contains(html, ">Executions<")
  assert_contains(html, "aria-selected=\"true\"")
  assert_contains(html, "executions body")
  assert_not_contains(html, "engines body")
  assert_not_contains(html, "templates body")
  assert_not_contains(html, "href=\"/config/templates")
  assert_not_contains(html, "href=\"/config/rule-metrics")
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
    |> element.to_document_string

  assert_contains(html, "data-testid=\"automation-selected-entity\"")
  assert_contains(html, "Template #12 selected")
  assert_not_contains(html, "Plantilla #12 seleccionada")
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
    |> element.to_document_string

  assert_contains(html, "Automatizaciones")
  assert_contains(html, "Crea trabajo automático en el Pool")
  assert_contains(html, "Regla #8 seleccionada en motor #3")
  assert_contains(html, ">Motores<")
  assert_contains(html, ">Plantillas<")
  assert_contains(html, ">Ejecuciones<")
  assert_not_contains(html, "Rule #8 selected")
}

fn primary_action() -> element.Element(msg) {
  button([attribute.attribute("data-testid", "automation-create-engine")], [
    text("Create engine"),
  ])
}
