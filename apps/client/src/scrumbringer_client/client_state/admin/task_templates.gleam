//// Task template admin state.

import gleam/option.{type Option}

import domain/remote.{type Remote, NotAsked}
import domain/workflow.{type TaskTemplate}
import scrumbringer_client/client_state/types as state_types

/// Represents task template admin state.
pub type Model {
  Model(
    task_templates_org: Remote(List(TaskTemplate)),
    task_templates_project: Remote(List(TaskTemplate)),
    task_templates_dialog_mode: Option(state_types.TaskTemplateDialogMode),
  )
}

/// Provides default task template admin state.
pub fn default_model() -> Model {
  Model(
    task_templates_org: NotAsked,
    task_templates_project: NotAsked,
    task_templates_dialog_mode: option.None,
  )
}
