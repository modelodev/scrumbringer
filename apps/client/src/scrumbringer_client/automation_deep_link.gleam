//// Deep-link targets for the unified automations console.

import gleam/int
import gleam/option as opt

import scrumbringer_client/permissions

pub type Selection {
  SelectedEngine(id: Int)
  SelectedRule(id: Int, engine_id: opt.Option(Int))
  SelectedTemplate(id: Int)
  SelectedExecution(id: Int)
}

pub fn section(selection: Selection) -> permissions.AdminSection {
  case selection {
    SelectedEngine(_) | SelectedRule(_, _) -> permissions.Workflows
    SelectedTemplate(_) -> permissions.TaskTemplates
    SelectedExecution(_) -> permissions.RuleMetrics
  }
}

pub fn query_params(selection: Selection) -> List(#(String, String)) {
  case selection {
    SelectedEngine(id) -> [#("engine", int.to_string(id))]
    SelectedRule(id, opt.Some(engine_id)) -> [
      #("engine", int.to_string(engine_id)),
      #("rule", int.to_string(id)),
    ]
    SelectedRule(id, opt.None) -> [#("rule", int.to_string(id))]
    SelectedTemplate(id) -> [#("template", int.to_string(id))]
    SelectedExecution(id) -> [#("execution", int.to_string(id))]
  }
}

pub fn engine_id(selection: opt.Option(Selection)) -> opt.Option(Int) {
  case selection {
    opt.Some(SelectedEngine(id)) | opt.Some(SelectedRule(_, opt.Some(id))) ->
      opt.Some(id)
    _ -> opt.None
  }
}

pub fn rule_id(selection: opt.Option(Selection)) -> opt.Option(Int) {
  case selection {
    opt.Some(SelectedRule(id, _)) -> opt.Some(id)
    _ -> opt.None
  }
}

pub fn template_id(selection: opt.Option(Selection)) -> opt.Option(Int) {
  case selection {
    opt.Some(SelectedTemplate(id)) -> opt.Some(id)
    _ -> opt.None
  }
}

pub fn execution_id(selection: opt.Option(Selection)) -> opt.Option(Int) {
  case selection {
    opt.Some(SelectedExecution(id)) -> opt.Some(id)
    _ -> opt.None
  }
}

pub fn label(selection: Selection) -> String {
  case selection {
    SelectedEngine(id) -> "Motor #" <> int.to_string(id) <> " seleccionado"
    SelectedRule(id, opt.Some(engine_id)) ->
      "Regla #"
      <> int.to_string(id)
      <> " seleccionada en motor #"
      <> int.to_string(engine_id)
    SelectedRule(id, opt.None) ->
      "Regla #" <> int.to_string(id) <> " seleccionada"
    SelectedTemplate(id) ->
      "Plantilla #" <> int.to_string(id) <> " seleccionada"
    SelectedExecution(id) ->
      "Ejecucion #" <> int.to_string(id) <> " seleccionada"
  }
}
