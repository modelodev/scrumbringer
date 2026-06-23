//// Root-state adapter for admin workflow views.

import gleam/option as opt

import domain/project.{type Project}
import domain/workflow.{type Workflow}

import scrumbringer_client/client_state/admin/rules as rules_state
import scrumbringer_client/client_state/admin/task_templates as task_templates_state
import scrumbringer_client/client_state/admin/task_types as task_types_state
import scrumbringer_client/client_state/admin/workflows as workflows_state
import scrumbringer_client/features/admin/views/workflows as workflows_view
import scrumbringer_client/features/admin/workflow_rules_view
import scrumbringer_client/features/admin/workflow_rules_view_config
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
    on_created: fn(Workflow) -> msg,
    on_updated: fn(Workflow) -> msg,
    on_deleted: fn(Int) -> msg,
    on_closed: msg,
    rules: workflow_rules_view_config.Callbacks(msg),
  )
}

pub fn from_state(
  locale: Locale,
  theme: Theme,
  selected_project: opt.Option(Project),
  selected_project_id: opt.Option(Int),
  workflows: workflows_state.Model,
  rules: rules_state.Model,
  task_templates: task_templates_state.Model,
  task_types: task_types_state.Model,
  callbacks: Callbacks(msg),
) -> workflows_view.Config(msg) {
  let selected_rules_view = case rules.rules_workflow_id {
    opt.Some(workflow_id) ->
      opt.Some(
        workflow_rules_view.view_workflow_rules(
          workflow_rules_view_config.from_state(
            locale,
            theme,
            workflow_id,
            rules,
            workflows,
            task_templates,
            task_types,
            callbacks.rules,
          ),
        ),
      )
    opt.None -> opt.None
  }

  workflows_view.Config(
    locale: locale,
    selected_project: selected_project,
    selected_project_id: selected_project_id,
    selected_rules_view: selected_rules_view,
    workflows: workflows.workflows_project,
    dialog_mode: workflows.workflows_dialog_mode,
    search_query: workflows.workflows_search,
    status_filter: workflows.workflows_status_filter,
    on_create_clicked: callbacks.on_create_clicked,
    on_search_changed: callbacks.on_search_changed,
    on_status_filter_changed: callbacks.on_status_filter_changed,
    on_rules_clicked: callbacks.on_rules_clicked,
    on_edit_clicked: callbacks.on_edit_clicked,
    on_delete_clicked: callbacks.on_delete_clicked,
    on_created: callbacks.on_created,
    on_updated: callbacks.on_updated,
    on_deleted: callbacks.on_deleted,
    on_closed: callbacks.on_closed,
  )
}
