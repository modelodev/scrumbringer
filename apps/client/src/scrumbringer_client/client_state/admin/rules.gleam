//// Rule admin state.

import gleam/option.{type Option}
import gleam/set

import domain/remote.{type Remote, NotAsked}
import domain/workflow.{type Rule, type RuleTemplate}
import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_state/types as state_types

/// Represents rule admin state.
pub type Model {
  Model(
    rules_workflow_id: Option(Int),
    rules: Remote(List(Rule)),
    rules_dialog_mode: Option(state_types.RuleDialogMode),
    rules_templates: Remote(List(RuleTemplate)),
    rules_attach_template_id: Option(Int),
    rules_attach_in_flight: Bool,
    rules_attach_error: Option(String),
    rules_expanded: set.Set(Int),
    attach_template_modal: Option(Int),
    attach_template_selected: Option(Int),
    attach_template_loading: Bool,
    detaching_templates: set.Set(#(Int, Int)),
    rules_metrics: Remote(api_workflows.WorkflowMetrics),
  )
}

/// Provides default rule admin state.
pub fn default_model() -> Model {
  Model(
    rules_workflow_id: option.None,
    rules: NotAsked,
    rules_dialog_mode: option.None,
    rules_templates: NotAsked,
    rules_attach_template_id: option.None,
    rules_attach_in_flight: False,
    rules_attach_error: option.None,
    rules_expanded: set.new(),
    attach_template_modal: option.None,
    attach_template_selected: option.None,
    attach_template_loading: False,
    detaching_templates: set.new(),
    rules_metrics: NotAsked,
  )
}
