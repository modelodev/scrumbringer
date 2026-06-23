//// Workflow admin state.

import gleam/option.{type Option}

import domain/remote.{type Remote, NotAsked}
import domain/workflow.{type Workflow}

/// Dialog mode for Workflow CRUD operations.
pub type WorkflowDialogMode {
  WorkflowDialogCreate
  WorkflowDialogEdit(Workflow)
  WorkflowDialogDelete(Workflow)
}

/// Represents workflow admin state.
pub type Model {
  Model(
    workflows_org: Remote(List(Workflow)),
    workflows_project: Remote(List(Workflow)),
    workflows_dialog_mode: Option(WorkflowDialogMode),
    workflows_search: String,
    workflows_status_filter: String,
    workflow_form_name: String,
    workflow_form_description: String,
    workflow_form_active: Bool,
    workflow_form_submitting: Bool,
    workflow_form_error: Option(String),
  )
}

/// Provides default workflow admin state.
pub fn default_model() -> Model {
  Model(
    workflows_org: NotAsked,
    workflows_project: NotAsked,
    workflows_dialog_mode: option.None,
    workflows_search: "",
    workflows_status_filter: "all",
    workflow_form_name: "",
    workflow_form_description: "",
    workflow_form_active: True,
    workflow_form_submitting: False,
    workflow_form_error: option.None,
  )
}
