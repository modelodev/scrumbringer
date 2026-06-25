//// Root adapter for project admin messages.

import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import domain/project.{type Project}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/projects as admin_projects
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/projects/project_list
import scrumbringer_client/features/projects/update as projects_update
import scrumbringer_client/features/route_support
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    projects_update.try_update(
      model.admin.projects,
      inner,
      context(model),
      feedback_context(model),
      error_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: projects_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let projects_update.Update(projects, fx, auth_policy, core_policy) = update

  route_support.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    let model = apply_core_policy(model, core_policy)
    #(
      client_state.update_admin(model, fn(admin) {
        update_projects(admin, fn(_) { projects })
      }),
      fx,
    )
  })
}

fn auth_error(policy: projects_update.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    projects_update.NoAuthCheck -> opt.None
    projects_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_projects(
  admin: admin_state.AdminModel,
  f: fn(admin_projects.Model) -> admin_projects.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, projects: f(admin.projects))
}

fn apply_core_policy(
  model: client_state.Model,
  policy: projects_update.CorePolicy,
) -> client_state.Model {
  case policy {
    projects_update.NoCoreChange -> model
    projects_update.CoreProjectCreated(project) -> after_created(model, project)
    projects_update.CoreProjectUpdated(project) -> after_updated(model, project)
    projects_update.CoreProjectDeleted(deleted_id) ->
      after_deleted(model, deleted_id)
  }
}

fn context(
  model: client_state.Model,
) -> projects_update.Context(client_state.Msg) {
  projects_update.Context(
    on_project_created: fn(result) {
      client_state.admin_msg(admin_messages.ProjectCreated(result))
    },
    on_project_updated: fn(result) {
      client_state.admin_msg(admin_messages.ProjectUpdated(result))
    },
    on_project_deleted: fn(result) {
      client_state.admin_msg(admin_messages.ProjectDeleted(result))
    },
    on_depth_reduction_previewed: fn(result) {
      client_state.admin_msg(admin_messages.ProjectEditDepthReductionPreviewed(
        result,
      ))
    },
    name_required: i18n.t(model.ui.locale, i18n_text.NameRequired),
  )
}

fn feedback_context(
  model: client_state.Model,
) -> projects_update.FeedbackContext(client_state.Msg) {
  projects_update.FeedbackContext(
    project_created: i18n.t(model.ui.locale, i18n_text.ProjectCreated),
    project_updated: i18n.t(model.ui.locale, i18n_text.Saved),
    project_deleted: i18n.t(model.ui.locale, i18n_text.Deleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn error_feedback_context(
  model: client_state.Model,
) -> projects_update.ErrorFeedbackContext(client_state.Msg) {
  projects_update.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
    on_error_toast: app_effects.toast_error,
  )
}

fn after_created(
  model: client_state.Model,
  project: Project,
) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      projects: project_list.prepend_or_single(core.projects, project),
      selected_project_id: opt.Some(project.id),
    )
  })
}

fn after_updated(
  model: client_state.Model,
  project: Project,
) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      projects: project_list.update_name(core.projects, project),
    )
  })
}

fn after_deleted(
  model: client_state.Model,
  deleted_id: opt.Option(Int),
) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      projects: project_list.remove(core.projects, deleted_id),
      selected_project_id: project_list.selected_after_delete(
        core.selected_project_id,
        deleted_id,
      ),
    )
  })
}
