//// Root-aware adapter for admin member-remove updates.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/member_remove
import scrumbringer_client/features/admin/member_root
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    member_remove.try_update(
      model.admin.members,
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
  update: member_remove.Update(client_state.Msg),
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let member_remove.Update(members, local_fx, auth_policy, refresh_policy) =
    update

  member_root.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    let model = member_root.set_members(model, members)
    let #(model, refresh_fx) = case refresh_policy {
      member_remove.NoRefresh -> #(model, effect.none())
      member_remove.RefreshSection -> refresh_section(model)
    }
    #(model, effect.batch([local_fx, refresh_fx]))
  })
}

fn auth_error(policy: member_remove.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    member_remove.NoAuthCheck -> opt.None
    member_remove.CheckAuth(err) -> opt.Some(err)
  }
}

fn context(model: client_state.Model) -> member_remove.Context(client_state.Msg) {
  member_remove.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_removed: fn(result) {
      client_state.admin_msg(admin_messages.MemberRemoved(result))
    },
  )
}

fn feedback_context(
  model: client_state.Model,
) -> member_remove.FeedbackContext(client_state.Msg) {
  member_remove.FeedbackContext(
    member_removed: i18n.t(model.ui.locale, i18n_text.MemberRemoved),
    on_success_toast: app_effects.toast_success,
  )
}

fn error_feedback_context(
  model: client_state.Model,
) -> member_remove.ErrorFeedbackContext(client_state.Msg) {
  member_remove.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}
