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
    rules_engine_id: Option(Int),
    rules: Remote(List(Rule)),
    rules_dialog_mode: Option(RuleDialogMode),
    rule_form_name: String,
    rule_form_goal: String,
    rule_form_subject: String,
    rule_form_task_type_id: String,
    rule_form_event: String,
    rule_form_card_scope: String,
    rule_form_template_search: String,
    rule_form_template_id: String,
    rule_form_active: Bool,
    rule_form_submitting: Bool,
    rule_form_error: Option(String),
    rules_expanded: set.Set(Int),
    rules_metrics: Remote(api_rule_metrics.WorkflowMetrics),
  )
}

/// Provides default rule admin state.
pub fn default_model() -> Model {
  Model(
    rules_engine_id: option.None,
    rules: NotAsked,
    rules_dialog_mode: option.None,
    rule_form_name: "",
    rule_form_goal: "",
    rule_form_subject: "task",
    rule_form_task_type_id: "",
    rule_form_event: "task_completed",
    rule_form_card_scope: "",
    rule_form_template_search: "",
    rule_form_template_id: "",
    rule_form_active: True,
    rule_form_submitting: False,
    rule_form_error: option.None,
    rules_expanded: set.new(),
    rules_metrics: NotAsked,
  )
}
