//// API token admin update handlers.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/api_token.{
  type ApiToken, type CreatedApiToken, type IntegrationUser, CreatedApiToken,
}
import domain/api_token_scope
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/api_tokens
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/admin/api_tokens as api_tokens_state
import scrumbringer_client/client_state/types.{
  DialogClosed, DialogOpen, Error as OperationError, Idle, InFlight,
}
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(
    on_integration_users_fetched: fn(ApiResult(List(IntegrationUser))) ->
      parent_msg,
    on_tokens_fetched: fn(ApiResult(List(ApiToken))) -> parent_msg,
    on_token_created: fn(ApiResult(CreatedApiToken)) -> parent_msg,
    on_token_renamed: fn(ApiResult(ApiToken)) -> parent_msg,
    on_token_revoked: fn(Int, ApiResult(Nil)) -> parent_msg,
    on_integration_deactivated: fn(Int, ApiResult(Nil)) -> parent_msg,
    on_token_secret_copy_finished: fn(Bool) -> parent_msg,
    name_required: String,
    integration_required: String,
    scope_required: String,
    copying: String,
    copied: String,
    copy_failed: String,
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(api_tokens_state.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: api_tokens_state.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.IntegrationUsersFetched(Ok(users)) ->
      #(
        api_tokens_state.ApiTokensModel(
          ..model,
          integration_users: Loaded(users),
        ),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.IntegrationUsersFetched(Error(err)) ->
      #(
        api_tokens_state.ApiTokensModel(..model, integration_users: Failed(err)),
        effect.none(),
      )
      |> with_auth_check(err)

    admin_messages.ApiTokensFetched(Ok(tokens)) ->
      #(
        api_tokens_state.ApiTokensModel(..model, tokens: Loaded(tokens)),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.ApiTokensFetched(Error(err)) ->
      #(
        api_tokens_state.ApiTokensModel(..model, tokens: Failed(err)),
        effect.none(),
      )
      |> with_auth_check(err)

    admin_messages.ApiTokenCreateDialogOpened ->
      open_token_dialog(model) |> without_auth_check

    admin_messages.ApiTokenCreateDialogClosed ->
      #(
        api_tokens_state.ApiTokensModel(
          ..model,
          token_dialog: DialogClosed(operation: Idle),
        ),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.ApiTokenNameChanged(value) ->
      update_token_form(model, fn(form) {
        api_tokens_state.ApiTokenForm(..form, name: value)
      })
      |> without_auth_check

    admin_messages.ApiTokenIntegrationChanged(value) ->
      update_token_form(model, fn(form) {
        api_tokens_state.ApiTokenForm(..form, integration: value)
      })
      |> without_auth_check

    admin_messages.ApiTokenProjectChanged(value) ->
      update_token_form(model, fn(form) {
        api_tokens_state.ApiTokenForm(
          ..form,
          project_id: parse_optional_int(value),
        )
      })
      |> without_auth_check

    admin_messages.ApiTokenScopeToggled(scope) ->
      update_token_form(model, fn(form) {
        api_tokens_state.ApiTokenForm(
          ..form,
          scopes: toggle_scope(form.scopes, scope),
        )
      })
      |> without_auth_check

    admin_messages.ApiTokenExpiresAtChanged(value) ->
      update_token_form(model, fn(form) {
        api_tokens_state.ApiTokenForm(..form, expires_at: value)
      })
      |> without_auth_check

    admin_messages.ApiTokenCreateSubmitted ->
      submit_token(model, context) |> without_auth_check

    admin_messages.ApiTokenCreated(Ok(created)) ->
      token_created(model, created, context) |> without_auth_check

    admin_messages.ApiTokenCreated(Error(err)) ->
      token_create_failed(model, err) |> with_auth_check(err)

    admin_messages.ApiTokenCreatedSecretDismissed ->
      #(
        api_tokens_state.ApiTokensModel(
          ..model,
          created_token: opt.None,
          token_secret_copy_status: opt.None,
        ),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.ApiTokenCreatedSecretCopyClicked(secret) ->
      handle_secret_copy_clicked(model, secret, context) |> without_auth_check

    admin_messages.ApiTokenCreatedSecretCopyFinished(ok) ->
      handle_secret_copy_finished(model, ok, context) |> without_auth_check

    admin_messages.ApiTokenRenameClicked(id, name) ->
      open_rename_dialog(model, id, name) |> without_auth_check

    admin_messages.ApiTokenRenameCancelled ->
      close_rename_dialog(model) |> without_auth_check

    admin_messages.ApiTokenRenameNameChanged(value) ->
      update_rename_form(model, fn(id, _) { #(id, value) })
      |> without_auth_check

    admin_messages.ApiTokenRenameSubmitted ->
      submit_rename(model, context) |> without_auth_check

    admin_messages.ApiTokenRenamed(Ok(token)) ->
      token_renamed(model, token) |> without_auth_check

    admin_messages.ApiTokenRenamed(Error(err)) ->
      token_rename_failed(model, err) |> with_auth_check(err)

    admin_messages.ApiTokenRevokeClicked(id) ->
      #(
        api_tokens_state.ApiTokensModel(..model, revoke_confirm: opt.Some(id)),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.ApiTokenRevokeCancelled ->
      #(
        api_tokens_state.ApiTokensModel(..model, revoke_confirm: opt.None),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.ApiTokenRevokeConfirmed ->
      submit_revoke(model, context) |> without_auth_check

    admin_messages.ApiTokenRevoked(_, Ok(_)) ->
      token_revoked(model, context) |> without_auth_check

    admin_messages.ApiTokenRevoked(_, Error(err)) ->
      #(
        api_tokens_state.ApiTokensModel(..model, revoke_confirm: opt.None),
        effect.none(),
      )
      |> with_auth_check(err)

    admin_messages.IntegrationDeactivateClicked(id) ->
      #(
        api_tokens_state.ApiTokensModel(
          ..model,
          integration_deactivate_confirm: opt.Some(id),
        ),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.IntegrationDeactivateCancelled ->
      #(
        api_tokens_state.ApiTokensModel(
          ..model,
          integration_deactivate_confirm: opt.None,
        ),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.IntegrationDeactivateConfirmed ->
      submit_integration_deactivate(model, context) |> without_auth_check

    admin_messages.IntegrationDeactivated(_, Ok(_)) ->
      integration_deactivated(model, context) |> without_auth_check

    admin_messages.IntegrationDeactivated(_, Error(err)) ->
      #(
        api_tokens_state.ApiTokensModel(
          ..model,
          integration_deactivate_confirm: opt.None,
        ),
        effect.none(),
      )
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(api_tokens_state.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck)
}

fn with_auth_check(
  result: #(api_tokens_state.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err))
}

fn with_policy(
  result: #(api_tokens_state.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy))
}

fn open_token_dialog(
  model: api_tokens_state.Model,
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  #(
    api_tokens_state.ApiTokensModel(
      ..model,
      token_dialog: DialogOpen(
        form: api_tokens_state.default_token_form(),
        operation: Idle,
      ),
      created_token: opt.None,
    ),
    effect.none(),
  )
}

fn update_token_form(
  model: api_tokens_state.Model,
  update: fn(api_tokens_state.Form) -> api_tokens_state.Form,
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  let dialog = case model.token_dialog {
    DialogClosed(operation) -> DialogClosed(operation)
    DialogOpen(form, operation) -> DialogOpen(update(form), operation)
  }
  #(
    api_tokens_state.ApiTokensModel(..model, token_dialog: dialog),
    effect.none(),
  )
}

fn submit_token(
  model: api_tokens_state.Model,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  case model.token_dialog {
    DialogClosed(_) -> #(model, effect.none())
    DialogOpen(form, _) ->
      case validate_token_form(form, context) {
        Ok(valid) -> #(
          api_tokens_state.ApiTokensModel(
            ..model,
            token_dialog: DialogOpen(form: form, operation: InFlight),
          ),
          api_tokens.create_token(valid, context.on_token_created),
        )
        Error(message) -> #(
          api_tokens_state.ApiTokensModel(
            ..model,
            token_dialog: DialogOpen(
              form: form,
              operation: OperationError(message),
            ),
          ),
          effect.none(),
        )
      }
  }
}

fn validate_token_form(
  form: api_tokens_state.Form,
  context: Context(parent_msg),
) -> Result(api_tokens_state.Form, String) {
  case string.trim(form.name), string.trim(form.integration), form.scopes {
    "", _, _ -> Error(context.name_required)
    _, "", _ -> Error(context.integration_required)
    _, _, [] -> Error(context.scope_required)
    name, integration, scopes ->
      Ok(
        api_tokens_state.ApiTokenForm(
          ..form,
          name: name,
          integration: integration,
          scopes: scopes,
        ),
      )
  }
}

fn token_created(
  model: api_tokens_state.Model,
  created: CreatedApiToken,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  let CreatedApiToken(api_token: api_token, token: bearer) = created
  let tokens = case model.tokens {
    Loaded(existing) -> Loaded([api_token, ..existing])
    other -> other
  }
  let model =
    api_tokens_state.ApiTokensModel(
      ..model,
      tokens: tokens,
      token_dialog: DialogClosed(operation: Idle),
      created_token: opt.Some(bearer),
      token_secret_copy_status: opt.None,
    )
  #(
    model,
    effect.batch([
      api_tokens.list_integration_users(context.on_integration_users_fetched),
      api_tokens.list_tokens(context.on_tokens_fetched),
    ]),
  )
}

fn open_rename_dialog(
  model: api_tokens_state.Model,
  id: Int,
  name: String,
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  #(
    api_tokens_state.ApiTokensModel(
      ..model,
      token_rename_dialog: DialogOpen(form: #(id, name), operation: Idle),
    ),
    effect.none(),
  )
}

fn close_rename_dialog(
  model: api_tokens_state.Model,
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  #(
    api_tokens_state.ApiTokensModel(
      ..model,
      token_rename_dialog: DialogClosed(operation: Idle),
    ),
    effect.none(),
  )
}

fn update_rename_form(
  model: api_tokens_state.Model,
  update: fn(Int, String) -> #(Int, String),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  let dialog = case model.token_rename_dialog {
    DialogClosed(operation) -> DialogClosed(operation)
    DialogOpen(form, operation) -> {
      let #(id, name) = form
      DialogOpen(update(id, name), operation)
    }
  }
  #(
    api_tokens_state.ApiTokensModel(..model, token_rename_dialog: dialog),
    effect.none(),
  )
}

fn submit_rename(
  model: api_tokens_state.Model,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  case model.token_rename_dialog {
    DialogClosed(_) -> #(model, effect.none())
    DialogOpen(form, _) -> {
      let #(id, name) = form
      case string.trim(name) {
        "" -> #(
          api_tokens_state.ApiTokensModel(
            ..model,
            token_rename_dialog: DialogOpen(
              form: form,
              operation: OperationError(context.name_required),
            ),
          ),
          effect.none(),
        )
        trimmed -> #(
          api_tokens_state.ApiTokensModel(
            ..model,
            token_rename_dialog: DialogOpen(
              form: #(id, trimmed),
              operation: InFlight,
            ),
          ),
          api_tokens.rename_token(id, trimmed, context.on_token_renamed),
        )
      }
    }
  }
}

fn token_renamed(
  model: api_tokens_state.Model,
  token: ApiToken,
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  let tokens = case model.tokens {
    Loaded(existing) ->
      existing
      |> list.map(fn(existing) {
        case existing.id == token.id {
          True -> token
          False -> existing
        }
      })
      |> Loaded
    other -> other
  }

  #(
    api_tokens_state.ApiTokensModel(
      ..model,
      tokens: tokens,
      token_rename_dialog: DialogClosed(operation: Idle),
    ),
    effect.none(),
  )
}

fn token_rename_failed(
  model: api_tokens_state.Model,
  err: ApiError,
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  let dialog = case model.token_rename_dialog {
    DialogClosed(_) -> DialogClosed(operation: OperationError(err.message))
    DialogOpen(form, _) ->
      DialogOpen(form: form, operation: OperationError(err.message))
  }
  #(
    api_tokens_state.ApiTokensModel(..model, token_rename_dialog: dialog),
    effect.none(),
  )
}

fn token_create_failed(
  model: api_tokens_state.Model,
  err: ApiError,
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  let dialog = case model.token_dialog {
    DialogClosed(_) -> DialogClosed(operation: OperationError(err.message))
    DialogOpen(form, _) ->
      DialogOpen(form: form, operation: OperationError(err.message))
  }
  #(
    api_tokens_state.ApiTokensModel(..model, token_dialog: dialog),
    effect.none(),
  )
}

fn submit_revoke(
  model: api_tokens_state.Model,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  case model.revoke_confirm {
    opt.None -> #(model, effect.none())
    opt.Some(id) -> #(
      model,
      api_tokens.revoke_token(id, fn(result) {
        context.on_token_revoked(id, result)
      }),
    )
  }
}

fn token_revoked(
  model: api_tokens_state.Model,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  let model = api_tokens_state.ApiTokensModel(..model, revoke_confirm: opt.None)
  #(
    model,
    effect.batch([
      api_tokens.list_tokens(context.on_tokens_fetched),
      api_tokens.list_integration_users(context.on_integration_users_fetched),
    ]),
  )
}

fn submit_integration_deactivate(
  model: api_tokens_state.Model,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  case model.integration_deactivate_confirm {
    opt.None -> #(model, effect.none())
    opt.Some(id) -> #(
      model,
      api_tokens.deactivate_integration_user(id, fn(result) {
        context.on_integration_deactivated(id, result)
      }),
    )
  }
}

fn integration_deactivated(
  model: api_tokens_state.Model,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  #(
    api_tokens_state.ApiTokensModel(
      ..model,
      integration_deactivate_confirm: opt.None,
    ),
    api_tokens.list_integration_users(context.on_integration_users_fetched),
  )
}

fn handle_secret_copy_clicked(
  model: api_tokens_state.Model,
  secret: String,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  #(
    api_tokens_state.ApiTokensModel(
      ..model,
      token_secret_copy_status: opt.Some(context.copying),
    ),
    copy_to_clipboard(secret, context.on_token_secret_copy_finished),
  )
}

fn handle_secret_copy_finished(
  model: api_tokens_state.Model,
  ok: Bool,
  context: Context(parent_msg),
) -> #(api_tokens_state.Model, Effect(parent_msg)) {
  let message = case ok {
    True -> context.copied
    False -> context.copy_failed
  }

  #(
    api_tokens_state.ApiTokensModel(
      ..model,
      token_secret_copy_status: opt.Some(message),
    ),
    effect.none(),
  )
}

fn parse_optional_int(value: String) -> opt.Option(Int) {
  case string.trim(value) {
    "" -> opt.None
    raw ->
      case int.parse(raw) {
        Ok(value) -> opt.Some(value)
        Error(_) -> opt.None
      }
  }
}

fn toggle_scope(
  scopes: List(api_token_scope.Scope),
  scope: api_token_scope.Scope,
) -> List(api_token_scope.Scope) {
  case list.contains(scopes, scope) {
    True -> list.filter(scopes, fn(existing) { existing != scope })
    False -> [scope, ..scopes]
  }
}

fn copy_to_clipboard(
  text: String,
  callback: fn(Bool) -> parent_msg,
) -> Effect(parent_msg) {
  effect.from(fn(dispatch) {
    client_ffi.copy_to_clipboard(text, fn(ok) { dispatch(callback(ok)) })
    Nil
  })
}
