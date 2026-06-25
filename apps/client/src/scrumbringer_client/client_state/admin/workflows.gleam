//// Automation engine admin state.

import gleam/option.{type Option}

import domain/remote.{type Remote, NotAsked}
import domain/workflow.{type Workflow}

/// Dialog mode for automation engine CRUD operations.
pub type EngineDialogMode {
  EngineDialogCreate
  EngineDialogEdit(Workflow)
  EngineDialogDelete(Workflow)
}

/// Represents automation engine admin state.
pub type Model {
  Model(
    engines_org: Remote(List(Workflow)),
    engines_project: Remote(List(Workflow)),
    engine_dialog_mode: Option(EngineDialogMode),
    engine_search: String,
    engine_status_filter: String,
    engine_form_name: String,
    engine_form_description: String,
    engine_form_active: Bool,
    engine_form_submitting: Bool,
    engine_form_error: Option(String),
  )
}

/// Provides default automation engine admin state.
pub fn default_model() -> Model {
  Model(
    engines_org: NotAsked,
    engines_project: NotAsked,
    engine_dialog_mode: option.None,
    engine_search: "",
    engine_status_filter: "all",
    engine_form_name: "",
    engine_form_description: "",
    engine_form_active: True,
    engine_form_submitting: False,
    engine_form_error: option.None,
  )
}
