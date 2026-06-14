import gleam/option

import lustre/effect

import domain/api_token_scope
import domain/org_role
import domain/remote
import scrumbringer_client/client_state/admin/api_tokens as api_tokens_state
import scrumbringer_client/client_state/types.{
  type ApiToken, ApiToken, ApiTokensModel, DialogClosed, DialogOpen, Idle,
  IntegrationUser,
}
import scrumbringer_client/features/admin/api_tokens_update
import scrumbringer_client/features/admin/msg as admin_messages

fn context() -> api_tokens_update.Context(Nil) {
  api_tokens_update.Context(
    on_integration_users_fetched: fn(_result) { Nil },
    on_tokens_fetched: fn(_result) { Nil },
    on_token_created: fn(_result) { Nil },
    on_token_renamed: fn(_result) { Nil },
    on_token_revoked: fn(_id, _result) { Nil },
    on_integration_deactivated: fn(_id, _result) { Nil },
    on_token_secret_copy_finished: fn(_ok) { Nil },
    name_required: "Name required",
    integration_required: "Integration required",
    scope_required: "Scope required",
    copying: "Copying",
    copied: "Copied",
    copy_failed: "Copy failed",
  )
}

fn token(name: String) -> ApiToken {
  ApiToken(
    id: 11,
    org_id: 1,
    integration_user_id: 9,
    integration_user_email: "bot",
    project_id: option.None,
    name: name,
    public_id: "pub",
    scopes: [api_token_scope.ProjectsRead],
    created_at: "2026-01-01T10:00:00Z",
    last_used_at: option.None,
    expires_at: option.None,
    revoked_at: option.None,
    expired: False,
  )
}

pub fn api_token_rename_opens_dialog_and_updates_loaded_token_test() {
  let model =
    ApiTokensModel(
      ..api_tokens_state.default_model(),
      tokens: remote.Loaded([token("old")]),
    )

  let assert option.Some(api_tokens_update.Update(opened, _, _)) =
    api_tokens_update.try_update(
      model,
      admin_messages.ApiTokenRenameClicked(11, "old"),
      context(),
    )
  let assert DialogOpen(form: #(11, "old"), operation: Idle) =
    opened.token_rename_dialog

  let assert option.Some(api_tokens_update.Update(renamed, _, _)) =
    api_tokens_update.try_update(
      opened,
      admin_messages.ApiTokenRenamed(Ok(token("new"))),
      context(),
    )
  let assert DialogClosed(operation: Idle) = renamed.token_rename_dialog
  let assert remote.Loaded([updated]) = renamed.tokens
  let ApiToken(name: updated_name, ..) = updated
  let assert "new" = updated_name
}

pub fn integration_deactivate_clears_confirmation_after_success_test() {
  let model =
    ApiTokensModel(
      ..api_tokens_state.default_model(),
      integration_users: remote.Loaded([
        IntegrationUser(
          id: 9,
          email: "bot",
          org_role: org_role.Member,
          created_at: "2026-01-01T10:00:00Z",
          active_token_count: 0,
        ),
      ]),
      integration_deactivate_confirm: option.Some(9),
    )

  let assert option.Some(api_tokens_update.Update(next, fx, _)) =
    api_tokens_update.try_update(
      model,
      admin_messages.IntegrationDeactivated(9, Ok(Nil)),
      context(),
    )

  let assert option.None = next.integration_deactivate_confirm
  let assert False = fx == effect.none()
}
