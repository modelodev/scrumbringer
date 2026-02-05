//// Member task dependencies state.

import gleam/option.{type Option}

import domain/remote.{type Remote, NotAsked}
import domain/task.{type Task, type TaskDependency}
import scrumbringer_client/client_state/dialog_mode

/// Represents member dependencies state.
pub type Model {
  Model(
    member_dependencies: Remote(List(TaskDependency)),
    member_dependency_dialog_mode: dialog_mode.DialogMode,
    member_dependency_search_query: String,
    member_dependency_candidates: Remote(List(Task)),
    member_dependency_selected_task_id: Option(Int),
    member_dependency_add_in_flight: Bool,
    member_dependency_add_error: Option(String),
    member_dependency_remove_in_flight: Option(Int),
  )
}

/// Provides default member dependencies state.
pub fn default_model() -> Model {
  Model(
    member_dependencies: NotAsked,
    member_dependency_dialog_mode: dialog_mode.DialogClosed,
    member_dependency_search_query: "",
    member_dependency_candidates: NotAsked,
    member_dependency_selected_task_id: option.None,
    member_dependency_add_in_flight: False,
    member_dependency_add_error: option.None,
    member_dependency_remove_in_flight: option.None,
  )
}
