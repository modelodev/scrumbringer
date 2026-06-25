//// Root adapter for capabilities admin messages.

import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/capabilities/types as capability_types
import scrumbringer_client/features/capabilities/update as capabilities_update
import scrumbringer_client/features/route_support
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    capabilities_update.try_update(
      model.admin.capabilities,
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
  update: capabilities_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let capabilities_update.Update(capabilities, fx, auth_policy) = update

  route_support.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    #(
      client_state.update_admin(model, fn(admin) {
        update_capabilities(admin, fn(_) { capabilities })
      }),
      fx,
    )
  })
}

fn auth_error(policy: capabilities_update.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    capabilities_update.NoAuthCheck -> opt.None
    capabilities_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_capabilities(
  admin: admin_state.AdminModel,
  f: fn(admin_capabilities.Model) -> admin_capabilities.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, capabilities: f(admin.capabilities))
}

fn context(
  model: client_state.Model,
) -> capability_types.Context(client_state.Msg) {
  capability_types.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_capabilities_fetched: fn(result) {
      client_state.admin_msg(admin_messages.MemberCapabilitiesFetched(result))
    },
    on_member_capabilities_saved: fn(result) {
      client_state.admin_msg(admin_messages.MemberCapabilitiesSaved(result))
    },
    on_capability_members_fetched: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityMembersFetched(result))
    },
    on_capability_members_saved: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityMembersSaved(result))
    },
    on_capability_created: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityCreated(result))
    },
    on_capability_updated: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityUpdated(result))
    },
    on_capability_deleted: fn(result) {
      client_state.admin_msg(admin_messages.CapabilityDeleted(result))
    },
    name_required: i18n.t(model.ui.locale, i18n_text.NameRequired),
  )
}

fn feedback_context(
  model: client_state.Model,
) -> capability_types.FeedbackContext(client_state.Msg) {
  capability_types.FeedbackContext(
    capability_created: i18n.t(model.ui.locale, i18n_text.CapabilityCreated),
    capability_updated: i18n.t(model.ui.locale, i18n_text.CapabilityUpdated),
    capability_deleted: i18n.t(model.ui.locale, i18n_text.CapabilityDeleted),
    member_capabilities_saved: i18n.t(model.ui.locale, i18n_text.SkillsSaved),
    capability_members_saved: i18n.t(model.ui.locale, i18n_text.MembersSaved),
    on_success_toast: app_effects.toast_success,
  )
}

fn error_feedback_context(
  model: client_state.Model,
) -> capability_types.ErrorFeedbackContext(client_state.Msg) {
  capability_types.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}
