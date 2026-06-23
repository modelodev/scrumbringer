//// Root-state adapter for automation rule lists.

import domain/workflow.{type Rule}
import gleam/option as opt

import scrumbringer_client/client_state/admin/rules as rules_state
import scrumbringer_client/client_state/admin/task_templates as task_templates_state
import scrumbringer_client/client_state/admin/task_types as task_types_state
import scrumbringer_client/client_state/admin/workflows as workflows_state
import scrumbringer_client/features/automations/rule_list
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/theme.{type Theme}

pub type Callbacks(msg) {
  Callbacks(
    on_back_clicked: msg,
    on_create_clicked: msg,
    on_rule_expanded: fn(Int) -> msg,
    on_edit_clicked: fn(Rule) -> msg,
    on_delete_clicked: fn(Rule) -> msg,
    on_rule_name_changed: fn(String) -> msg,
    on_rule_goal_changed: fn(String) -> msg,
    on_rule_subject_changed: fn(String) -> msg,
    on_rule_task_type_changed: fn(String) -> msg,
    on_rule_event_changed: fn(String) -> msg,
    on_rule_card_scope_changed: fn(String) -> msg,
    on_rule_template_search_changed: fn(String) -> msg,
    on_rule_template_changed: fn(String) -> msg,
    on_rule_active_changed: fn(Bool) -> msg,
    on_rule_submitted: msg,
    on_rule_delete_confirmed: msg,
    on_rule_panel_closed: msg,
    on_noop: msg,
  )
}

pub fn from_state(
  locale: Locale,
  theme: Theme,
  workflow_id: Int,
  rules: rules_state.Model,
  workflows: workflows_state.Model,
  task_templates: task_templates_state.Model,
  task_types: task_types_state.Model,
  selected_rule_id: opt.Option(Int),
  callbacks: Callbacks(msg),
) -> rule_list.Config(msg) {
  rule_list.Config(
    locale: locale,
    theme: theme,
    workflow_id: workflow_id,
    selected_rule_id: selected_rule_id,
    workflow_name: rule_list.engine_name_from_remotes(
      workflows.workflows_org,
      workflows.workflows_project,
      workflow_id,
    ),
    rules: rules,
    workflows_org: workflows.workflows_org,
    workflows_project: workflows.workflows_project,
    task_types: task_types.task_types,
    task_templates_org: task_templates.task_templates_org,
    task_templates_project: task_templates.task_templates_project,
    on_back_clicked: callbacks.on_back_clicked,
    on_create_clicked: callbacks.on_create_clicked,
    on_rule_expanded: callbacks.on_rule_expanded,
    on_edit_clicked: callbacks.on_edit_clicked,
    on_delete_clicked: callbacks.on_delete_clicked,
    on_rule_name_changed: callbacks.on_rule_name_changed,
    on_rule_goal_changed: callbacks.on_rule_goal_changed,
    on_rule_subject_changed: callbacks.on_rule_subject_changed,
    on_rule_task_type_changed: callbacks.on_rule_task_type_changed,
    on_rule_event_changed: callbacks.on_rule_event_changed,
    on_rule_card_scope_changed: callbacks.on_rule_card_scope_changed,
    on_rule_template_search_changed: callbacks.on_rule_template_search_changed,
    on_rule_template_changed: callbacks.on_rule_template_changed,
    on_rule_active_changed: callbacks.on_rule_active_changed,
    on_rule_submitted: callbacks.on_rule_submitted,
    on_rule_delete_confirmed: callbacks.on_rule_delete_confirmed,
    on_rule_panel_closed: callbacks.on_rule_panel_closed,
    on_noop: callbacks.on_noop,
  )
}
