//// Root adapter for organization settings admin messages.

import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/assignments_route
import scrumbringer_client/features/admin/member_root
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/org_settings
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    org_settings.try_update(
      model.admin.members,
      inner,
      context(),
      feedback_context(model),
    )
  {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  update: org_settings.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let org_settings.Update(members, local_fx, auth_policy, root_policy) = update

  member_root.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    let model = member_root.set_members(model, members)
    apply_root_policy(model, local_fx, root_policy)
  })
}

fn auth_error(policy: org_settings.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    org_settings.NoAuthCheck -> opt.None
    org_settings.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_root_policy(
  model: client_state.Model,
  local_fx: effect.Effect(client_state.Msg),
  policy: org_settings.RootPolicy,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  case policy {
    org_settings.NoRootPolicy -> #(model, local_fx)

    org_settings.StartAssignmentsFetch(users) ->
      start_assignments_fetch(model, local_fx, users)

    org_settings.UpdateCurrentUser(updated) -> #(
      update_current_user(model, updated),
      local_fx,
    )
  }
}

fn start_assignments_fetch(
  model: client_state.Model,
  local_fx: effect.Effect(client_state.Msg),
  users: List(OrgUser),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let #(model, assignments_fx) =
    assignments_route.start_user_projects_fetch(model, users)
  #(model, effect.batch([local_fx, assignments_fx]))
}

fn update_current_user(
  model: client_state.Model,
  updated: OrgUser,
) -> client_state.Model {
  let user = org_settings.current_user_after_saved(model.core.user, updated)
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(..core, user: user)
  })
}

fn context() -> org_settings.Context(client_state.Msg) {
  org_settings.Context(
    on_org_settings_saved: fn(user_id, result) {
      client_state.admin_msg(admin_messages.OrgSettingsSaved(user_id, result))
    },
    on_org_settings_deleted: fn(result) {
      client_state.admin_msg(admin_messages.OrgSettingsDeleted(result))
    },
  )
}

fn feedback_context(
  model: client_state.Model,
) -> org_settings.FeedbackContext(client_state.Msg) {
  org_settings.FeedbackContext(
    role_updated: i18n.t(model.ui.locale, i18n_text.RoleUpdated),
    user_deleted: i18n.t(model.ui.locale, i18n_text.UserDeleted),
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_success_toast: app_effects.toast_success,
    on_warning_toast: app_effects.toast_warning,
  )
}
