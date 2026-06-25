//// Root adapter for API token admin messages.

import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/features/admin/api_tokens_update
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/route_support
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    api_tokens_update.try_update(model.admin.api_tokens, inner, context(model))
  {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn context(
  model: client_state.Model,
) -> api_tokens_update.Context(client_state.Msg) {
  api_tokens_update.Context(
    on_integration_users_fetched: fn(result) {
      client_state.admin_msg(admin_messages.IntegrationUsersFetched(result))
    },
    on_tokens_fetched: fn(result) {
      client_state.admin_msg(admin_messages.ApiTokensFetched(result))
    },
    on_token_created: fn(result) {
      client_state.admin_msg(admin_messages.ApiTokenCreated(result))
    },
    on_token_renamed: fn(result) {
      client_state.admin_msg(admin_messages.ApiTokenRenamed(result))
    },
    on_token_revoked: fn(id, result) {
      client_state.admin_msg(admin_messages.ApiTokenRevoked(id, result))
    },
    on_integration_deactivated: fn(id, result) {
      client_state.admin_msg(admin_messages.IntegrationDeactivated(id, result))
    },
    on_token_secret_copy_finished: fn(ok) {
      client_state.admin_msg(admin_messages.ApiTokenCreatedSecretCopyFinished(
        ok,
      ))
    },
    name_required: i18n.t(model.ui.locale, i18n_text.NameRequired),
    integration_required: i18n.t(model.ui.locale, i18n_text.IntegrationRequired),
    scope_required: i18n.t(model.ui.locale, i18n_text.ScopeRequired),
    copying: i18n.t(model.ui.locale, i18n_text.Copying),
    copied: i18n.t(model.ui.locale, i18n_text.Copied),
    copy_failed: i18n.t(model.ui.locale, i18n_text.CopyFailed),
  )
}

fn auth_error(policy: api_tokens_update.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    api_tokens_update.NoAuthCheck -> opt.None
    api_tokens_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn apply_update(
  model: client_state.Model,
  update: api_tokens_update.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let api_tokens_update.Update(api_tokens, local_fx, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(auth_error(auth_policy)),
    fn() {
      let model =
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(..admin, api_tokens: api_tokens)
        })
      #(model, local_fx)
    },
  )
}
