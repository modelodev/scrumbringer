import gleam/option.{Some}
import gleam/string
import lustre/element
import lustre/element/html.{div, text}

import scrumbringer_client/features/automations/console as automations_console

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn render(mode: automations_console.Mode) -> String {
  automations_console.Config(
    selected_project_id: Some(7),
    mode: mode,
    active_engines_count: 2,
    rules_count: 4,
    templates_count: 3,
    created_tasks_count: 12,
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
  assert_contains(html, "Automatizaciones")
  assert_contains(
    html,
    "Crea trabajo automatico en el Pool sin asignarlo a nadie.",
  )
  assert_contains(html, "motores activos")
  assert_contains(html, "reglas")
  assert_contains(html, "plantillas")
  assert_contains(html, "tasks creadas")
  assert_contains(html, ">2<")
  assert_contains(html, ">4<")
  assert_contains(html, ">3<")
  assert_contains(html, ">12<")
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
  assert_contains(html, ">Motores<")
  assert_contains(html, ">Plantillas<")
  assert_contains(html, ">Ejecuciones<")
  assert_contains(html, "aria-selected=\"true\"")
  assert_contains(html, "executions body")
  assert_not_contains(html, "engines body")
  assert_not_contains(html, "templates body")
  assert_not_contains(html, "href=\"/config/templates")
  assert_not_contains(html, "href=\"/config/rule-metrics")
}
