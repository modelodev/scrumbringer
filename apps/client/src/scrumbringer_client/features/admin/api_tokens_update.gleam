//// API token admin update handlers.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/api_token_scope
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/api_tokens
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/admin/api_tokens as api_tokens_state
import scrumbringer_client/client_state/types.{
  type ApiToken, type ApiTokenForm, type ApiTokensModel, type CreatedApiToken,
  type IntegrationUser, ApiTokenForm, ApiTokensModel, CreatedApiToken,
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
  Update(ApiTokensModel, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: ApiTokensModel,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.IntegrationUsersFetched(Ok(users)) ->
      #(
        ApiTokensModel(..model, integration_users: Loaded(users)),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.IntegrationUsersFetched(Error(err)) ->
      #(ApiTokensModel(..model, integration_users: Failed(err)), effect.none())
      |> with_auth_check(err)

    admin_messages.ApiTokensFetched(Ok(tokens)) ->
      #(ApiTokensModel(..model, tokens: Loaded(tokens)), effect.none())
      |> without_auth_check

    admin_messages.ApiTokensFetched(Error(err)) ->
      #(ApiTokensModel(..model, tokens: Failed(err)), effect.none())
      |> with_auth_check(err)

    admin_messages.ApiTokenCreateDialogOpened ->
      open_token_dialog(model) |> without_auth_check

    admin_messages.ApiTokenCreateDialogClosed ->
      #(
        ApiTokensModel(..model, token_dialog: DialogClosed(operation: Idle)),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.ApiTokenNameChanged(value) ->
      update_token_form(model, fn(form) { ApiTokenForm(..form, name: value) })
      |> without_auth_check

    admin_messages.ApiTokenIntegrationChanged(value) ->
      update_token_form(model, fn(form) {
        ApiTokenForm(..form, integration: value)
      })
      |> without_auth_check

    admin_messages.ApiTokenProjectChanged(value) ->
      update_token_form(model, fn(form) {
        ApiTokenForm(..form, project_id: parse_optional_int(value))
      })
      |> without_auth_check

    admin_messages.ApiTokenScopeToggled(scope) ->
      update_token_form(model, fn(form) {
        ApiTokenForm(..form, scopes: toggle_scope(form.scopes, scope))
      })
      |> without_auth_check

    admin_messages.ApiTokenExpiresAtChanged(value) ->
      update_token_form(model, fn(form) {
        ApiTokenForm(..form, expires_at: value)
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
        ApiTokensModel(
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
      #(ApiTokensModel(..model, revoke_confirm: opt.Some(id)), effect.none())
      |> without_auth_check

    admin_messages.ApiTokenRevokeCancelled ->
      #(ApiTokensModel(..model, revoke_confirm: opt.None), effect.none())
      |> without_auth_check

    admin_messages.ApiTokenRevokeConfirmed ->
      submit_revoke(model, context) |> without_auth_check

    admin_messages.ApiTokenRevoked(_, Ok(_)) ->
      token_revoked(model, context) |> without_auth_check

    admin_messages.ApiTokenRevoked(_, Error(err)) ->
      #(ApiTokensModel(..model, revoke_confirm: opt.None), effect.none())
      |> with_auth_check(err)

    admin_messages.IntegrationDeactivateClicked(id) ->
      #(
        ApiTokensModel(..model, integration_deactivate_confirm: opt.Some(id)),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.IntegrationDeactivateCancelled ->
      #(
        ApiTokensModel(..model, integration_deactivate_confirm: opt.None),
        effect.none(),
      )
      |> without_auth_check

    admin_messages.IntegrationDeactivateConfirmed ->
      submit_integration_deactivate(model, context) |> without_auth_check

    admin_messages.IntegrationDeactivated(_, Ok(_)) ->
      integration_deactivated(model, context) |> without_auth_check

    admin_messages.IntegrationDeactivated(_, Error(err)) ->
      #(
        ApiTokensModel(..model, integration_deactivate_confirm: opt.None),
        effect.none(),
      )
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(ApiTokensModel, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck)
}

fn with_auth_check(
  result: #(ApiTokensModel, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err))
}

fn with_policy(
  result: #(ApiTokensModel, Effect(parent_msg)),
  auth_policy: AuthPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy))
}

fn open_token_dialog(
  model: ApiTokensModel,
) -> #(ApiTokensModel, Effect(parent_msg)) {
  #(
    ApiTokensModel(
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
  model: ApiTokensModel,
  update: fn(ApiTokenForm) -> ApiTokenForm,
) -> #(ApiTokensModel, Effect(parent_msg)) {
  let dialog = case model.token_dialog {
    DialogClosed(operation) -> DialogClosed(operation)
    DialogOpen(form, operation) -> DialogOpen(update(form), operation)
  }
  #(ApiTokensModel(..model, token_dialog: dialog), effect.none())
}

fn submit_token(
  model: ApiTokensModel,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
  case model.token_dialog {
    DialogClosed(_) -> #(model, effect.none())
    DialogOpen(form, _) ->
      case validate_token_form(form, context) {
        Ok(valid) -> #(
          ApiTokensModel(
            ..model,
            token_dialog: DialogOpen(form: form, operation: InFlight),
          ),
          api_tokens.create_token(valid, context.on_token_created),
        )
        Error(message) -> #(
          ApiTokensModel(
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
  form: ApiTokenForm,
  context: Context(parent_msg),
) -> Result(ApiTokenForm, String) {
  case string.trim(form.name), string.trim(form.integration), form.scopes {
    "", _, _ -> Error(context.name_required)
    _, "", _ -> Error(context.integration_required)
    _, _, [] -> Error(context.scope_required)
    name, integration, scopes ->
      Ok(
        ApiTokenForm(
          ..form,
          name: name,
          integration: integration,
          scopes: scopes,
        ),
      )
  }
}

fn token_created(
  model: ApiTokensModel,
  created: CreatedApiToken,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
  let CreatedApiToken(api_token: api_token, token: bearer) = created
  let tokens = case model.tokens {
    Loaded(existing) -> Loaded([api_token, ..existing])
    other -> other
  }
  let model =
    ApiTokensModel(
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
  model: ApiTokensModel,
  id: Int,
  name: String,
) -> #(ApiTokensModel, Effect(parent_msg)) {
  #(
    ApiTokensModel(
      ..model,
      token_rename_dialog: DialogOpen(form: #(id, name), operation: Idle),
    ),
    effect.none(),
  )
}

fn close_rename_dialog(
  model: ApiTokensModel,
) -> #(ApiTokensModel, Effect(parent_msg)) {
  #(
    ApiTokensModel(..model, token_rename_dialog: DialogClosed(operation: Idle)),
    effect.none(),
  )
}

fn update_rename_form(
  model: ApiTokensModel,
  update: fn(Int, String) -> #(Int, String),
) -> #(ApiTokensModel, Effect(parent_msg)) {
  let dialog = case model.token_rename_dialog {
    DialogClosed(operation) -> DialogClosed(operation)
    DialogOpen(form, operation) -> {
      let #(id, name) = form
      DialogOpen(update(id, name), operation)
    }
  }
  #(ApiTokensModel(..model, token_rename_dialog: dialog), effect.none())
}

fn submit_rename(
  model: ApiTokensModel,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
  case model.token_rename_dialog {
    DialogClosed(_) -> #(model, effect.none())
    DialogOpen(form, _) -> {
      let #(id, name) = form
      case string.trim(name) {
        "" -> #(
          ApiTokensModel(
            ..model,
            token_rename_dialog: DialogOpen(
              form: form,
              operation: OperationError(context.name_required),
            ),
          ),
          effect.none(),
        )
        trimmed -> #(
          ApiTokensModel(
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
  model: ApiTokensModel,
  token: ApiToken,
) -> #(ApiTokensModel, Effect(parent_msg)) {
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
    ApiTokensModel(
      ..model,
      tokens: tokens,
      token_rename_dialog: DialogClosed(operation: Idle),
    ),
    effect.none(),
  )
}

fn token_rename_failed(
  model: ApiTokensModel,
  err: ApiError,
) -> #(ApiTokensModel, Effect(parent_msg)) {
  let dialog = case model.token_rename_dialog {
    DialogClosed(_) -> DialogClosed(operation: OperationError(err.message))
    DialogOpen(form, _) ->
      DialogOpen(form: form, operation: OperationError(err.message))
  }
  #(ApiTokensModel(..model, token_rename_dialog: dialog), effect.none())
}

fn token_create_failed(
  model: ApiTokensModel,
  err: ApiError,
) -> #(ApiTokensModel, Effect(parent_msg)) {
  let dialog = case model.token_dialog {
    DialogClosed(_) -> DialogClosed(operation: OperationError(err.message))
    DialogOpen(form, _) ->
      DialogOpen(form: form, operation: OperationError(err.message))
  }
  #(ApiTokensModel(..model, token_dialog: dialog), effect.none())
}

fn submit_revoke(
  model: ApiTokensModel,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
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
  model: ApiTokensModel,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
  let model = ApiTokensModel(..model, revoke_confirm: opt.None)
  #(
    model,
    effect.batch([
      api_tokens.list_tokens(context.on_tokens_fetched),
      api_tokens.list_integration_users(context.on_integration_users_fetched),
    ]),
  )
}

fn submit_integration_deactivate(
  model: ApiTokensModel,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
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
  model: ApiTokensModel,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
  #(
    ApiTokensModel(..model, integration_deactivate_confirm: opt.None),
    api_tokens.list_integration_users(context.on_integration_users_fetched),
  )
}

fn handle_secret_copy_clicked(
  model: ApiTokensModel,
  secret: String,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
  #(
    ApiTokensModel(..model, token_secret_copy_status: opt.Some(context.copying)),
    copy_to_clipboard(secret, context.on_token_secret_copy_finished),
  )
}

fn handle_secret_copy_finished(
  model: ApiTokensModel,
  ok: Bool,
  context: Context(parent_msg),
) -> #(ApiTokensModel, Effect(parent_msg)) {
  let message = case ok {
    True -> context.copied
    False -> context.copy_failed
  }

  #(
    ApiTokensModel(..model, token_secret_copy_status: opt.Some(message)),
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
