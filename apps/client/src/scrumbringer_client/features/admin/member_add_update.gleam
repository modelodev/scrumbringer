//// Root-aware adapter for admin member-add updates.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/member_add
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
    member_add.try_update(
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
  update: member_add.Update(client_state.Msg),
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let member_add.Update(members, local_fx, auth_policy, refresh_policy) = update

  member_root.apply_auth_check(
    model,
    member_root.auth_check_before(auth_error(auth_policy)),
    fn() {
      let model = member_root.set_members(model, members)
      let #(model, refresh_fx) = case refresh_policy {
        member_add.NoRefresh -> #(model, effect.none())
        member_add.RefreshSection -> refresh_section(model)
      }
      #(model, effect.batch([local_fx, refresh_fx]))
    },
  )
}

fn auth_error(policy: member_add.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    member_add.NoAuthCheck -> opt.None
    member_add.CheckAuth(err) -> opt.Some(err)
  }
}

fn context(model: client_state.Model) -> member_add.Context(client_state.Msg) {
  member_add.Context(
    selected_project_id: model.core.selected_project_id,
    select_user_first: i18n.t(model.ui.locale, i18n_text.SelectUserFirst),
    on_member_added: fn(result) {
      client_state.admin_msg(admin_messages.MemberAdded(result))
    },
  )
}

fn feedback_context(
  model: client_state.Model,
) -> member_add.FeedbackContext(client_state.Msg) {
  member_add.FeedbackContext(
    member_added: i18n.t(model.ui.locale, i18n_text.MemberAdded),
    on_success_toast: app_effects.toast_success,
  )
}

fn error_feedback_context(
  model: client_state.Model,
) -> member_add.ErrorFeedbackContext(client_state.Msg) {
  member_add.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}
