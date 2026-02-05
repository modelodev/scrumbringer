//// Workflow admin state.

import gleam/option.{type Option}

import domain/remote.{type Remote, NotAsked}
import domain/workflow.{type Workflow}
import scrumbringer_client/client_state/types as state_types

/// Represents workflow admin state.
pub type Model {
  Model(
    workflows_org: Remote(List(Workflow)),
    workflows_project: Remote(List(Workflow)),
    workflows_dialog_mode: Option(state_types.WorkflowDialogMode),
  )
}

/// Provides default workflow admin state.
pub fn default_model() -> Model {
  Model(
    workflows_org: NotAsked,
    workflows_project: NotAsked,
    workflows_dialog_mode: option.None,
  )
}
