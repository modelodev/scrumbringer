//// Root adapter for invite admin messages.

import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/invites as admin_invites
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/invites/update as invites_update
import scrumbringer_client/features/route_support
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    invites_update.try_update(
      model.admin.invites,
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
  update: invites_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let invites_update.Update(invites, fx, auth_policy) = update

  route_support.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_invites(admin, fn(_) { invites })
      }),
      fx,
    )
  })
}

fn auth_error(policy: invites_update.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    invites_update.NoAuthCheck -> opt.None
    invites_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_invites(
  admin: admin_state.AdminModel,
  f: fn(admin_invites.Model) -> admin_invites.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, invites: f(admin.invites))
}

fn context(
  model: client_state.Model,
) -> invites_update.Context(client_state.Msg) {
  invites_update.Context(
    on_links_fetched: fn(result) {
      client_state.admin_msg(admin_messages.InviteLinksFetched(result))
    },
    on_link_created: fn(result) {
      client_state.admin_msg(admin_messages.InviteLinkCreated(result))
    },
    on_link_regenerated: fn(result) {
      client_state.admin_msg(admin_messages.InviteLinkRegenerated(result))
    },
    on_link_invalidated: fn(result) {
      client_state.admin_msg(admin_messages.InviteLinkInvalidated(result))
    },
    on_copy_finished: fn(ok) {
      client_state.admin_msg(admin_messages.InviteLinkCopyFinished(ok))
    },
    email_required: i18n.t(model.ui.locale, i18n_text.EmailRequired),
    copying: i18n.t(model.ui.locale, i18n_text.Copying),
    copied: i18n.t(model.ui.locale, i18n_text.Copied),
    copy_failed: i18n.t(model.ui.locale, i18n_text.CopyFailed),
  )
}

fn feedback_context(
  model: client_state.Model,
) -> invites_update.FeedbackContext(client_state.Msg) {
  invites_update.FeedbackContext(
    invite_link_created: i18n.t(model.ui.locale, i18n_text.InviteLinkCreated),
    invite_link_regenerated: i18n.t(
      model.ui.locale,
      i18n_text.InviteLinkRegenerated,
    ),
    invite_link_invalidated: i18n.t(
      model.ui.locale,
      i18n_text.InviteLinkInvalidated,
    ),
    on_success_toast: app_effects.toast_success,
  )
}

fn error_feedback_context(
  model: client_state.Model,
) -> invites_update.ErrorFeedbackContext(client_state.Msg) {
  invites_update.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}
