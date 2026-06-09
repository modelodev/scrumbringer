//// Root-aware adapter for admin release-all updates.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/member_release_all
import scrumbringer_client/features/admin/member_root
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    member_release_all.try_update(
      model.admin.members,
      inner,
      context(model),
      feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: member_release_all.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let member_release_all.Update(members, local_fx, auth_policy) = update

  member_root.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    member_root.apply_members_result(model, members, local_fx)
  })
}

fn auth_error(policy: member_release_all.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    member_release_all.NoAuthCheck -> opt.None
    member_release_all.CheckAuth(err) -> opt.Some(err)
  }
}

fn context(
  model: client_state.Model,
) -> member_release_all.Context(client_state.Msg) {
  member_release_all.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_release_all_result: fn(result) {
      client_state.admin_msg(admin_messages.MemberReleaseAllResult(result))
    },
  )
}

fn feedback_context(
  model: client_state.Model,
) -> member_release_all.FeedbackContext(client_state.Msg) {
  member_release_all.FeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    release_all_self_error: i18n.t(
      model.ui.locale,
      i18n_text.ReleaseAllSelfError,
    ),
    release_all_none: fn(user_name) {
      i18n.t(model.ui.locale, i18n_text.ReleaseAllNone(user_name))
    },
    release_all_success: fn(released_count, user_name) {
      i18n.t(
        model.ui.locale,
        i18n_text.ReleaseAllSuccess(released_count, user_name),
      )
    },
    release_all_error: fn(user_name) {
      i18n.t(model.ui.locale, i18n_text.ReleaseAllError(user_name))
    },
    on_success_toast: app_effects.toast_success,
    on_warning_toast: app_effects.toast_warning,
  )
}
