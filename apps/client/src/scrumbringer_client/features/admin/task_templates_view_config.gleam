//// Root-state adapter for admin task template views.

import gleam/option as opt

import domain/project.{type Project}
import domain/workflow.{type TaskTemplate}

import scrumbringer_client/client_state/admin/task_templates as task_templates_state
import scrumbringer_client/client_state/admin/task_types as task_types_state
import scrumbringer_client/features/admin/task_templates_view
import scrumbringer_client/i18n/locale.{type Locale}

pub type Callbacks(msg) {
  Callbacks(
    on_create_clicked: msg,
    on_edit_clicked: fn(TaskTemplate) -> msg,
    on_delete_clicked: fn(TaskTemplate) -> msg,
    on_search_changed: fn(String) -> msg,
    on_created: fn(TaskTemplate) -> msg,
    on_updated: fn(TaskTemplate) -> msg,
    on_deleted: fn(Int) -> msg,
    on_closed: msg,
  )
}

pub fn from_state(
  locale: Locale,
  selected_project: opt.Option(Project),
  selected_project_id: opt.Option(Int),
  task_templates: task_templates_state.Model,
  task_types: task_types_state.Model,
  callbacks: Callbacks(msg),
) -> task_templates_view.Config(msg) {
  task_templates_view.Config(
    locale: locale,
    selected_project: selected_project,
    selected_project_id: selected_project_id,
    templates: task_templates.task_templates_project,
    dialog_mode: task_templates.task_templates_dialog_mode,
    task_types: task_types.task_types,
    search_query: task_templates.task_templates_search,
    on_create_clicked: callbacks.on_create_clicked,
    on_edit_clicked: callbacks.on_edit_clicked,
    on_delete_clicked: callbacks.on_delete_clicked,
    on_search_changed: callbacks.on_search_changed,
    on_created: callbacks.on_created,
    on_updated: callbacks.on_updated,
    on_deleted: callbacks.on_deleted,
    on_closed: callbacks.on_closed,
  )
}
