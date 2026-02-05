//// Task type admin state.

import gleam/option.{type Option}

import domain/remote.{type Remote, NotAsked}
import domain/task_type.{type TaskType}
import scrumbringer_client/client_state/types as state_types

/// Represents task type admin state.
pub type Model {
  Model(
    task_types: Remote(List(TaskType)),
    task_types_project_id: Option(Int),
    task_types_dialog_mode: Option(state_types.TaskTypeDialogMode),
    task_types_create_name: String,
    task_types_create_icon: String,
    task_types_create_icon_search: String,
    task_types_create_icon_category: String,
    task_types_create_capability_id: Option(String),
    task_types_create_in_flight: Bool,
    task_types_create_error: Option(String),
    task_types_icon_preview: state_types.IconPreview,
  )
}

/// Provides default task type admin state.
pub fn default_model() -> Model {
  Model(
    task_types: NotAsked,
    task_types_project_id: option.None,
    task_types_dialog_mode: option.None,
    task_types_create_name: "",
    task_types_create_icon: "",
    task_types_create_icon_search: "",
    task_types_create_icon_category: "all",
    task_types_create_capability_id: option.None,
    task_types_create_in_flight: False,
    task_types_create_error: option.None,
    task_types_icon_preview: state_types.IconIdle,
  )
}
