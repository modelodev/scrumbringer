//// Root-state adapter for the automation template library.

import gleam/option as opt

import domain/project.{type Project}
import domain/workflow.{type TaskTemplate}

import scrumbringer_client/client_state/admin/task_templates as task_templates_state
import scrumbringer_client/client_state/admin/task_types as task_types_state
import scrumbringer_client/features/automations/template_library
import scrumbringer_client/i18n/locale.{type Locale}

pub type Callbacks(msg) {
  Callbacks(
    on_create_clicked: msg,
    on_edit_clicked: fn(TaskTemplate) -> msg,
    on_delete_clicked: fn(TaskTemplate) -> msg,
    on_search_changed: fn(String) -> msg,
    on_name_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_type_changed: fn(String) -> msg,
    on_priority_changed: fn(String) -> msg,
    on_submitted: fn(opt.Option(Int)) -> msg,
    on_delete_confirmed: msg,
    on_closed: msg,
  )
}

pub fn from_state(
  locale: Locale,
  selected_project: opt.Option(Project),
  selected_project_id: opt.Option(Int),
  task_templates: task_templates_state.Model,
  task_types: task_types_state.Model,
  selected_template_id: opt.Option(Int),
  callbacks: Callbacks(msg),
) -> template_library.Config(msg) {
  template_library.Config(
    locale: locale,
    selected_project: selected_project,
    selected_project_id: selected_project_id,
    templates: task_templates.task_templates_project,
    selected_template_id: selected_template_id,
    dialog_mode: task_templates.task_templates_dialog_mode,
    task_types: task_types.task_types,
    search_query: task_templates.task_templates_search,
    form_name: task_templates.task_template_form_name,
    form_description: task_templates.task_template_form_description,
    form_type_id: task_templates.task_template_form_type_id,
    form_priority: task_templates.task_template_form_priority,
    form_submitting: task_templates.task_template_form_submitting,
    form_error: task_templates.task_template_form_error,
    on_create_clicked: callbacks.on_create_clicked,
    on_edit_clicked: callbacks.on_edit_clicked,
    on_delete_clicked: callbacks.on_delete_clicked,
    on_search_changed: callbacks.on_search_changed,
    on_name_changed: callbacks.on_name_changed,
    on_description_changed: callbacks.on_description_changed,
    on_type_changed: callbacks.on_type_changed,
    on_priority_changed: callbacks.on_priority_changed,
    on_submitted: callbacks.on_submitted,
    on_delete_confirmed: callbacks.on_delete_confirmed,
    on_closed: callbacks.on_closed,
  )
}
