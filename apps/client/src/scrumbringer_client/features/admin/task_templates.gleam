//// Admin task template update handlers.
////
//// ## Mission
////
//// Own task template fetch, dialog state, and CRUD transitions for admin.
////
//// ## Responsibilities
////
//// - Project task template fetch state
//// - Task template dialog open/close
//// - Task template CRUD component events
//// - Project-scoped task template fetch effect
////
//// ## Relations
////
//// - **features/pool/update.gleam**: Routes task template messages here
//// - **client_update.gleam**: Calls fetch_task_templates for admin sections

import gleam/int
import gleam/option as opt
import gleam/result
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/remote.{Failed, Loaded, Loading}
import domain/workflow.{type TaskTemplate}
import scrumbringer_client/client_state.{
  type Model, type Msg, pool_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/features/admin/scoped_remote_list
import scrumbringer_client/features/pool/msg as pool_messages

import scrumbringer_client/api/workflows/task_templates as api_task_templates

type Success {
  TaskTemplateCreated
  TaskTemplateUpdated
  TaskTemplateDeleted
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    task_template_created: String,
    task_template_updated: String,
    task_template_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_template_saved: fn(Result(TaskTemplate, ApiError)) -> parent_msg,
    on_template_deleted: fn(Int, Result(Nil, ApiError)) -> parent_msg,
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(admin_task_templates.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  state: admin_task_templates.Model,
  inner: pool_messages.Msg,
  feedback: FeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.TaskTemplatesProjectFetched(Ok(templates)) ->
      #(project_fetched_ok(state, templates), effect.none())
      |> without_auth_check

    pool_messages.TaskTemplatesProjectFetched(Error(err)) ->
      #(project_fetched_error(state, err), effect.none())
      |> with_auth_check(err)

    pool_messages.TaskTemplatesSearchChanged(query) ->
      #(search_changed(state, query), effect.none())
      |> without_auth_check

    pool_messages.OpenTaskTemplateDialog(mode) ->
      #(open_dialog(state, mode), effect.none())
      |> without_auth_check

    pool_messages.CloseTaskTemplateDialog ->
      #(close_dialog(state), effect.none())
      |> without_auth_check

    pool_messages.TaskTemplateNameChanged(value) ->
      #(update_form_name(state, value), effect.none())
      |> without_auth_check

    pool_messages.TaskTemplateDescriptionChanged(value) ->
      #(update_form_description(state, value), effect.none())
      |> without_auth_check

    pool_messages.TaskTemplateTypeChanged(value) ->
      #(update_form_type_id(state, value), effect.none())
      |> without_auth_check

    pool_messages.TaskTemplatePriorityChanged(value) ->
      #(update_form_priority(state, value), effect.none())
      |> without_auth_check

    pool_messages.TaskTemplateFormSubmitted(project_id) ->
      submit_form(state, project_id, feedback)
      |> without_auth_check

    pool_messages.TaskTemplateSaved(Ok(template)) ->
      #(
        template_saved(state, template),
        success_effect(success_for_saved(state), feedback),
      )
      |> without_auth_check

    pool_messages.TaskTemplateSaved(Error(err)) ->
      #(form_error(state, err.message), effect.none())
      |> with_auth_check(err)

    pool_messages.TaskTemplateDeleteConfirmed ->
      confirm_delete(state, feedback)
      |> without_auth_check

    pool_messages.TaskTemplateDeleteFinished(template_id, Ok(Nil)) ->
      #(
        template_deleted(state, template_id),
        success_effect(TaskTemplateDeleted, feedback),
      )
      |> without_auth_check

    pool_messages.TaskTemplateDeleteFinished(_template_id, Error(err)) ->
      #(form_error(state, err.message), effect.none())
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(admin_task_templates.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  let #(state, fx) = result
  opt.Some(Update(state, fx, NoAuthCheck))
}

fn with_auth_check(
  result: #(admin_task_templates.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  let #(state, fx) = result
  opt.Some(Update(state, fx, CheckAuth(err)))
}

fn project_fetched_ok(
  state: admin_task_templates.Model,
  templates: List(TaskTemplate),
) -> admin_task_templates.Model {
  admin_task_templates.Model(..state, task_templates_project: Loaded(templates))
}

fn project_fetched_error(
  state: admin_task_templates.Model,
  err: ApiError,
) -> admin_task_templates.Model {
  admin_task_templates.Model(..state, task_templates_project: Failed(err))
}

fn search_changed(
  state: admin_task_templates.Model,
  query: String,
) -> admin_task_templates.Model {
  admin_task_templates.Model(..state, task_templates_search: query)
}

fn open_dialog(
  state: admin_task_templates.Model,
  mode: admin_task_templates.TaskTemplateDialogMode,
) -> admin_task_templates.Model {
  case mode {
    admin_task_templates.TaskTemplateDialogCreate ->
      admin_task_templates.Model(
        ..state,
        task_templates_dialog_mode: opt.Some(mode),
        task_template_form_name: "",
        task_template_form_description: "",
        task_template_form_type_id: "",
        task_template_form_priority: "3",
        task_template_form_submitting: False,
        task_template_form_error: opt.None,
      )
    admin_task_templates.TaskTemplateDialogEdit(template) ->
      admin_task_templates.Model(
        ..state,
        task_templates_dialog_mode: opt.Some(mode),
        task_template_form_name: template.name,
        task_template_form_description: template_description(template),
        task_template_form_type_id: int.to_string(template.type_id),
        task_template_form_priority: int.to_string(template.priority),
        task_template_form_submitting: False,
        task_template_form_error: opt.None,
      )
    admin_task_templates.TaskTemplateDialogDelete(_) ->
      admin_task_templates.Model(
        ..state,
        task_templates_dialog_mode: opt.Some(mode),
        task_template_form_submitting: False,
        task_template_form_error: opt.None,
      )
  }
}

fn close_dialog(state: admin_task_templates.Model) -> admin_task_templates.Model {
  admin_task_templates.Model(
    ..state,
    task_templates_dialog_mode: opt.None,
    task_template_form_submitting: False,
    task_template_form_error: opt.None,
  )
}

fn template_description(template: TaskTemplate) -> String {
  case template.description {
    opt.Some(value) -> value
    opt.None -> ""
  }
}

fn update_form_name(
  state: admin_task_templates.Model,
  value: String,
) -> admin_task_templates.Model {
  admin_task_templates.Model(
    ..state,
    task_template_form_name: value,
    task_template_form_error: opt.None,
  )
}

fn update_form_description(
  state: admin_task_templates.Model,
  value: String,
) -> admin_task_templates.Model {
  admin_task_templates.Model(
    ..state,
    task_template_form_description: value,
    task_template_form_error: opt.None,
  )
}

fn update_form_type_id(
  state: admin_task_templates.Model,
  value: String,
) -> admin_task_templates.Model {
  admin_task_templates.Model(
    ..state,
    task_template_form_type_id: value,
    task_template_form_error: opt.None,
  )
}

fn update_form_priority(
  state: admin_task_templates.Model,
  value: String,
) -> admin_task_templates.Model {
  admin_task_templates.Model(
    ..state,
    task_template_form_priority: value,
    task_template_form_error: opt.None,
  )
}

fn submit_form(
  state: admin_task_templates.Model,
  project_id: opt.Option(Int),
  feedback: FeedbackContext(parent_msg),
) -> #(admin_task_templates.Model, Effect(parent_msg)) {
  case state.task_templates_dialog_mode {
    opt.Some(admin_task_templates.TaskTemplateDialogCreate) ->
      submit_create(state, project_id, feedback)
    opt.Some(admin_task_templates.TaskTemplateDialogEdit(template)) ->
      submit_update(state, template.id, feedback)
    opt.Some(admin_task_templates.TaskTemplateDialogDelete(_)) -> #(
      state,
      effect.none(),
    )
    opt.None -> #(state, effect.none())
  }
}

fn submit_create(
  state: admin_task_templates.Model,
  project_id: opt.Option(Int),
  feedback: FeedbackContext(parent_msg),
) -> #(admin_task_templates.Model, Effect(parent_msg)) {
  case project_id {
    opt.None -> #(form_error(state, "Select a project first"), effect.none())
    opt.Some(id) ->
      case parse_form(state) {
        Error(message) -> #(form_error(state, message), effect.none())
        Ok(form) -> {
          let submitting = set_submitting(state)
          let fx =
            api_task_templates.create_project_template(
              id,
              form.name,
              form.description,
              form.type_id,
              form.priority,
              feedback.on_template_saved,
            )
          #(submitting, fx)
        }
      }
  }
}

fn submit_update(
  state: admin_task_templates.Model,
  template_id: Int,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_task_templates.Model, Effect(parent_msg)) {
  case parse_form(state) {
    Error(message) -> #(form_error(state, message), effect.none())
    Ok(form) -> {
      let submitting = set_submitting(state)
      let fx =
        api_task_templates.update_template(
          template_id,
          form.name,
          form.description,
          form.type_id,
          form.priority,
          feedback.on_template_saved,
        )
      #(submitting, fx)
    }
  }
}

fn confirm_delete(
  state: admin_task_templates.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_task_templates.Model, Effect(parent_msg)) {
  case state.task_templates_dialog_mode {
    opt.Some(admin_task_templates.TaskTemplateDialogDelete(template)) -> {
      let submitting = set_submitting(state)
      let fx =
        api_task_templates.delete_template(template.id, fn(result) {
          feedback.on_template_deleted(template.id, result)
        })
      #(submitting, fx)
    }
    _ -> #(state, effect.none())
  }
}

type TemplateForm {
  TemplateForm(name: String, description: String, type_id: Int, priority: Int)
}

fn parse_form(state: admin_task_templates.Model) -> Result(TemplateForm, String) {
  let name = string.trim(state.task_template_form_name)
  case name {
    "" -> Error("Template name is required")
    _ -> {
      use type_id <- result.try(parse_type_id(state.task_template_form_type_id))
      use priority <- result.try(parse_priority(
        state.task_template_form_priority,
      ))
      Ok(TemplateForm(
        name: name,
        description: state.task_template_form_description,
        type_id: type_id,
        priority: priority,
      ))
    }
  }
}

fn parse_type_id(value: String) -> Result(Int, String) {
  case int.parse(value) {
    Ok(id) if id > 0 -> Ok(id)
    _ -> Error("Task type is required")
  }
}

fn parse_priority(value: String) -> Result(Int, String) {
  case int.parse(value) {
    Ok(priority) if priority >= 1 && priority <= 5 -> Ok(priority)
    _ -> Error("Priority must be between 1 and 5")
  }
}

fn set_submitting(
  state: admin_task_templates.Model,
) -> admin_task_templates.Model {
  admin_task_templates.Model(
    ..state,
    task_template_form_submitting: True,
    task_template_form_error: opt.None,
  )
}

fn form_error(
  state: admin_task_templates.Model,
  message: String,
) -> admin_task_templates.Model {
  admin_task_templates.Model(
    ..state,
    task_template_form_submitting: False,
    task_template_form_error: opt.Some(message),
  )
}

fn success_for_saved(state: admin_task_templates.Model) -> Success {
  case state.task_templates_dialog_mode {
    opt.Some(admin_task_templates.TaskTemplateDialogEdit(_)) ->
      TaskTemplateUpdated
    _ -> TaskTemplateCreated
  }
}

fn template_saved(
  state: admin_task_templates.Model,
  template: TaskTemplate,
) -> admin_task_templates.Model {
  case state.task_templates_dialog_mode {
    opt.Some(admin_task_templates.TaskTemplateDialogEdit(_)) ->
      template_updated(state, template)
    _ -> template_created(state, template)
  }
}

fn template_created(
  state: admin_task_templates.Model,
  template: TaskTemplate,
) -> admin_task_templates.Model {
  let #(org, project) =
    scoped_remote_list.prepend_for_scope(
      state.task_templates_org,
      state.task_templates_project,
      template.project_id,
      template,
    )

  admin_task_templates.Model(
    task_templates_org: org,
    task_templates_project: project,
    task_templates_dialog_mode: opt.None,
    task_templates_search: state.task_templates_search,
    task_template_form_name: "",
    task_template_form_description: "",
    task_template_form_type_id: "",
    task_template_form_priority: "3",
    task_template_form_submitting: False,
    task_template_form_error: opt.None,
  )
}

fn template_updated(
  state: admin_task_templates.Model,
  updated_template: TaskTemplate,
) -> admin_task_templates.Model {
  let org =
    scoped_remote_list.replace_by_id(
      state.task_templates_org,
      updated_template,
      fn(template: TaskTemplate) { template.id },
    )
  let project =
    scoped_remote_list.replace_by_id(
      state.task_templates_project,
      updated_template,
      fn(template: TaskTemplate) { template.id },
    )

  admin_task_templates.Model(
    task_templates_org: org,
    task_templates_project: project,
    task_templates_dialog_mode: opt.None,
    task_templates_search: state.task_templates_search,
    task_template_form_name: updated_template.name,
    task_template_form_description: template_description(updated_template),
    task_template_form_type_id: int.to_string(updated_template.type_id),
    task_template_form_priority: int.to_string(updated_template.priority),
    task_template_form_submitting: False,
    task_template_form_error: opt.None,
  )
}

fn template_deleted(
  state: admin_task_templates.Model,
  template_id: Int,
) -> admin_task_templates.Model {
  let org =
    scoped_remote_list.remove_by_id(
      state.task_templates_org,
      template_id,
      fn(template: TaskTemplate) { template.id },
    )
  let project =
    scoped_remote_list.remove_by_id(
      state.task_templates_project,
      template_id,
      fn(template: TaskTemplate) { template.id },
    )

  admin_task_templates.Model(
    task_templates_org: org,
    task_templates_project: project,
    task_templates_dialog_mode: opt.None,
    task_templates_search: state.task_templates_search,
    task_template_form_name: "",
    task_template_form_description: "",
    task_template_form_type_id: "",
    task_template_form_priority: "3",
    task_template_form_submitting: False,
    task_template_form_error: opt.None,
  )
}

fn success_effect(
  success: Success,
  feedback: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  let message = case success {
    TaskTemplateCreated -> feedback.task_template_created
    TaskTemplateUpdated -> feedback.task_template_updated
    TaskTemplateDeleted -> feedback.task_template_deleted
  }

  feedback.on_success_toast(message)
}

// =============================================================================
// Fetch Helpers
// =============================================================================

/// Fetch task templates for admin panel (project-scoped only).
pub fn fetch_task_templates(model: Model) -> #(Model, Effect(Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> {
      let fetch_effect =
        api_task_templates.list_project_templates(project_id, fn(result) {
          pool_msg(pool_messages.TaskTemplatesProjectFetched(result))
        })
      let model =
        update_admin(model, fn(admin) {
          update_task_templates(admin, fn(task_templates_state) {
            admin_task_templates.Model(
              ..task_templates_state,
              task_templates_project: Loading,
            )
          })
        })
      #(model, fetch_effect)
    }
    opt.None -> #(model, effect.none())
  }
}

fn update_task_templates(
  admin: admin_state.AdminModel,
  f: fn(admin_task_templates.Model) -> admin_task_templates.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, task_templates: f(admin.task_templates))
}
