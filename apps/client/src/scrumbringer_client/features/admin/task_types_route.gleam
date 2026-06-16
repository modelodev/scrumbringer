//// Root adapter for task type admin messages.

import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/route_support
import scrumbringer_client/features/task_types/update as task_types_update
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    task_types_update.try_update(
      model.admin.task_types,
      inner,
      context(model),
      feedback_context(model),
      error_feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_update(model, update, refresh_section))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: task_types_update.Update(client_state.Msg),
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_types_update.Update(
    task_types,
    local_fx,
    auth_policy,
    refresh_policy,
  ) = update

  route_support.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    let model =
      client_state.update_admin(model, fn(admin) {
        update_task_types(admin, fn(_) { task_types })
      })
    let #(model, refresh_fx) = case refresh_policy {
      task_types_update.NoRefresh -> #(model, effect.none())
      task_types_update.RefreshSection -> refresh_section(model)
    }
    #(model, effect.batch([local_fx, refresh_fx]))
  })
}

fn auth_error(policy: task_types_update.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    task_types_update.NoAuthCheck -> opt.None
    task_types_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_task_types(
  admin: admin_state.AdminModel,
  f: fn(admin_task_types.Model) -> admin_task_types.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, task_types: f(admin.task_types))
}

fn context(
  model: client_state.Model,
) -> task_types_update.Context(client_state.Msg) {
  task_types_update.Context(
    selected_project_id: model.core.selected_project_id,
    on_task_type_created: fn(result) {
      client_state.admin_msg(admin_messages.TaskTypeCreated(result))
    },
    select_project_first: i18n.t(model.ui.locale, i18n_text.SelectProjectFirst),
    name_and_icon_required: i18n.t(
      model.ui.locale,
      i18n_text.NameAndIconRequired,
    ),
  )
}

fn feedback_context(
  model: client_state.Model,
) -> task_types_update.FeedbackContext(client_state.Msg) {
  task_types_update.FeedbackContext(
    task_type_created: i18n.t(model.ui.locale, i18n_text.TaskTypeCreated),
    task_type_updated: i18n.t(model.ui.locale, i18n_text.TaskTypeUpdated),
    task_type_deleted: i18n.t(model.ui.locale, i18n_text.TaskTypeDeleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn error_feedback_context(
  model: client_state.Model,
) -> task_types_update.ErrorFeedbackContext(client_state.Msg) {
  task_types_update.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}
