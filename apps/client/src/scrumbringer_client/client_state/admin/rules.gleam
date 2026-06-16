//// Rule admin state.

import gleam/option.{type Option}
import gleam/set

import domain/remote.{type Remote, NotAsked}
import domain/workflow.{type Rule}
import scrumbringer_client/api/workflows/rule_metrics as api_rule_metrics

/// Dialog mode for Rule CRUD operations.
pub type RuleDialogMode {
  RuleDialogCreate
  RuleDialogEdit(Rule)
  RuleDialogDelete(Rule)
}

/// Represents rule admin state.
pub type Model {
  Model(
    rules_workflow_id: Option(Int),
    rules: Remote(List(Rule)),
    rules_dialog_mode: Option(RuleDialogMode),
    rules_expanded: set.Set(Int),
    attach_template_modal: Option(Int),
    attach_template_selected: Option(Int),
    attach_template_loading: Bool,
    detaching_templates: set.Set(#(Int, Int)),
    rules_metrics: Remote(api_rule_metrics.WorkflowMetrics),
  )
}

/// Provides default rule admin state.
pub fn default_model() -> Model {
  Model(
    rules_workflow_id: option.None,
    rules: NotAsked,
    rules_dialog_mode: option.None,
    rules_expanded: set.new(),
    attach_template_modal: option.None,
    attach_template_selected: option.None,
    attach_template_loading: False,
    detaching_templates: set.new(),
    rules_metrics: NotAsked,
  )
}
