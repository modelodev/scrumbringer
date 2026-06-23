//// Task template admin state.

import gleam/option.{type Option}

import domain/remote.{type Remote, NotAsked}
import domain/workflow.{type TaskTemplate}

/// Dialog mode for Task Template CRUD operations.
pub type TaskTemplateDialogMode {
  TaskTemplateDialogCreate
  TaskTemplateDialogEdit(TaskTemplate)
  TaskTemplateDialogDelete(TaskTemplate)
}

/// Represents task template admin state.
pub type Model {
  Model(
    task_templates_org: Remote(List(TaskTemplate)),
    task_templates_project: Remote(List(TaskTemplate)),
    task_templates_dialog_mode: Option(TaskTemplateDialogMode),
    task_templates_search: String,
    task_template_form_name: String,
    task_template_form_description: String,
    task_template_form_type_id: String,
    task_template_form_priority: String,
    task_template_form_submitting: Bool,
    task_template_form_error: Option(String),
  )
}

/// Provides default task template admin state.
pub fn default_model() -> Model {
  Model(
    task_templates_org: NotAsked,
    task_templates_project: NotAsked,
    task_templates_dialog_mode: option.None,
    task_templates_search: "",
    task_template_form_name: "",
    task_template_form_description: "",
    task_template_form_type_id: "",
    task_template_form_priority: "3",
    task_template_form_submitting: False,
    task_template_form_error: option.None,
  )
}
