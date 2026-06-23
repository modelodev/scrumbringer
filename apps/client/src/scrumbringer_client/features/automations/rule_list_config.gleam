//// Root-state adapter for automation rule lists.

import domain/workflow.{type Rule}

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
    on_attach_modal_opened: fn(Int) -> msg,
    on_attach_modal_closed: msg,
    on_template_detached: fn(Int, Int) -> msg,
    on_template_selected: fn(Int) -> msg,
    on_attach_submitted: msg,
    on_rule_created: fn(Rule) -> msg,
    on_rule_updated: fn(Rule) -> msg,
    on_rule_deleted: fn(Int) -> msg,
    on_rule_dialog_closed: msg,
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
  callbacks: Callbacks(msg),
) -> rule_list.Config(msg) {
  rule_list.Config(
    locale: locale,
    theme: theme,
    workflow_id: workflow_id,
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
    on_attach_modal_opened: callbacks.on_attach_modal_opened,
    on_attach_modal_closed: callbacks.on_attach_modal_closed,
    on_template_detached: callbacks.on_template_detached,
    on_template_selected: callbacks.on_template_selected,
    on_attach_submitted: callbacks.on_attach_submitted,
    on_rule_created: callbacks.on_rule_created,
    on_rule_updated: callbacks.on_rule_updated,
    on_rule_deleted: callbacks.on_rule_deleted,
    on_rule_dialog_closed: callbacks.on_rule_dialog_closed,
    on_noop: callbacks.on_noop,
  )
}
