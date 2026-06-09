//// Root-aware adapter for admin member-role updates.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/member_role
import scrumbringer_client/features/admin/member_root
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    member_role.try_update(
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

pub fn success_effect(
  model: client_state.Model,
) -> effect.Effect(client_state.Msg) {
  member_role.success_effect(feedback_context(model))
}

pub fn error_effect(
  model: client_state.Model,
  err: ApiError,
) -> effect.Effect(client_state.Msg) {
  member_role.error_effect(err, feedback_context(model))
}

fn apply_update(
  model: client_state.Model,
  update: member_role.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let member_role.Update(members, local_fx, auth_policy) = update

  member_root.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    member_root.apply_members_result(model, members, local_fx)
  })
}

fn auth_error(policy: member_role.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    member_role.NoAuthCheck -> opt.None
    member_role.CheckAuth(err) -> opt.Some(err)
  }
}

fn context(model: client_state.Model) -> member_role.Context(client_state.Msg) {
  member_role.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_role_changed: fn(result) {
      client_state.admin_msg(admin_messages.MemberRoleChanged(result))
    },
  )
}

fn feedback_context(
  model: client_state.Model,
) -> member_role.FeedbackContext(client_state.Msg) {
  member_role.FeedbackContext(
    role_updated: i18n.t(model.ui.locale, i18n_text.RoleUpdated),
    cannot_demote_last_manager: i18n.t(
      model.ui.locale,
      i18n_text.CannotDemoteLastManager,
    ),
    on_success_toast: app_effects.toast_success,
    on_warning_toast: app_effects.toast_warning,
    on_error_toast: app_effects.toast_error,
  )
}
