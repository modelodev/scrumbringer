//// Root-state adapter for the automation engines list.

import gleam/option as opt

import domain/project.{type Project}
import domain/workflow.{type Workflow}

import scrumbringer_client/automation_deep_link
import scrumbringer_client/client_state/admin/rules as rules_state
import scrumbringer_client/client_state/admin/task_templates as task_templates_state
import scrumbringer_client/client_state/admin/task_types as task_types_state
import scrumbringer_client/client_state/admin/workflows as engine_state
import scrumbringer_client/features/automations/engine_list
import scrumbringer_client/features/automations/rule_list
import scrumbringer_client/features/automations/rule_list_config
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/theme.{type Theme}

pub type Callbacks(msg) {
  Callbacks(
    on_create_clicked: msg,
    on_search_changed: fn(String) -> msg,
    on_status_filter_changed: fn(String) -> msg,
    on_rules_clicked: fn(Int) -> msg,
    on_edit_clicked: fn(Workflow) -> msg,
    on_delete_clicked: fn(Workflow) -> msg,
    on_name_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_active_changed: fn(Bool) -> msg,
    on_submitted: fn(opt.Option(Int)) -> msg,
    on_delete_confirmed: msg,
    on_closed: msg,
    rules: rule_list_config.Callbacks(msg),
  )
}

pub fn from_state(
  locale: Locale,
  theme: Theme,
  selected_project: opt.Option(Project),
  selected_project_id: opt.Option(Int),
  engines_state: engine_state.Model,
  rules: rules_state.Model,
  task_templates: task_templates_state.Model,
  task_types: task_types_state.Model,
  depth_names: List(scope_view.DepthName),
  selection: opt.Option(automation_deep_link.Selection),
  callbacks: Callbacks(msg),
) -> engine_list.Config(msg) {
  let selected_rules_view = case rules.rules_engine_id {
    opt.Some(engine_id) ->
      opt.Some(
        rule_list.view(rule_list_config.from_state(
          locale,
          theme,
          engine_id,
          rules,
          engines_state,
          task_templates,
          task_types,
          depth_names,
          automation_deep_link.rule_id(selection),
          callbacks.rules,
        )),
      )
    opt.None -> opt.None
  }

  engine_list.Config(
    locale: locale,
    selected_project: selected_project,
    selected_project_id: selected_project_id,
    selected_rules_view: selected_rules_view,
    engines: engines_state.engines_project,
    selected_engine_id: automation_deep_link.engine_id(selection),
    selected_rule_id: automation_deep_link.rule_id(selection),
    dialog_mode: engines_state.engine_dialog_mode,
    search_query: engines_state.engine_search,
    status_filter: engines_state.engine_status_filter,
    form_name: engines_state.engine_form_name,
    form_description: engines_state.engine_form_description,
    form_active: engines_state.engine_form_active,
    form_submitting: engines_state.engine_form_submitting,
    form_error: engines_state.engine_form_error,
    on_create_clicked: callbacks.on_create_clicked,
    on_search_changed: callbacks.on_search_changed,
    on_status_filter_changed: callbacks.on_status_filter_changed,
    on_rules_clicked: callbacks.on_rules_clicked,
    on_edit_clicked: callbacks.on_edit_clicked,
    on_delete_clicked: callbacks.on_delete_clicked,
    on_name_changed: callbacks.on_name_changed,
    on_description_changed: callbacks.on_description_changed,
    on_active_changed: callbacks.on_active_changed,
    on_submitted: callbacks.on_submitted,
    on_delete_confirmed: callbacks.on_delete_confirmed,
    on_closed: callbacks.on_closed,
  )
}
