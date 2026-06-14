//// API token admin state.

import gleam/option

import domain/api_token_scope
import domain/remote.{NotAsked}
import scrumbringer_client/client_state/types as state_types

pub type Model =
  state_types.ApiTokensModel

pub fn default_token_form() -> state_types.ApiTokenForm {
  state_types.ApiTokenForm(
    name: "",
    integration: "",
    project_id: option.None,
    scopes: default_scopes(),
    expires_at: "",
  )
}

pub fn default_scopes() -> List(api_token_scope.Scope) {
  [api_token_scope.ProjectsRead, api_token_scope.TasksRead]
}

pub fn default_model() -> Model {
  state_types.ApiTokensModel(
    integration_users: NotAsked,
    tokens: NotAsked,
    token_dialog: state_types.DialogClosed(operation: state_types.Idle),
    token_rename_dialog: state_types.DialogClosed(operation: state_types.Idle),
    created_token: option.None,
    token_secret_copy_status: option.None,
    revoke_confirm: option.None,
    integration_deactivate_confirm: option.None,
  )
}
