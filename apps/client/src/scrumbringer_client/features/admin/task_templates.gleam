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

import gleam/option as opt

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

    pool_messages.TaskTemplateCrudCreated(template) ->
      #(
        template_created(state, template),
        success_effect(TaskTemplateCreated, feedback),
      )
      |> without_auth_check

    pool_messages.TaskTemplateCrudUpdated(template) ->
      #(
        template_updated(state, template),
        success_effect(TaskTemplateUpdated, feedback),
      )
      |> without_auth_check

    pool_messages.TaskTemplateCrudDeleted(template_id) ->
      #(
        template_deleted(state, template_id),
        success_effect(TaskTemplateDeleted, feedback),
      )
      |> without_auth_check

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
  admin_task_templates.Model(
    ..state,
    task_templates_dialog_mode: opt.Some(mode),
  )
}

fn close_dialog(state: admin_task_templates.Model) -> admin_task_templates.Model {
  admin_task_templates.Model(..state, task_templates_dialog_mode: opt.None)
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
