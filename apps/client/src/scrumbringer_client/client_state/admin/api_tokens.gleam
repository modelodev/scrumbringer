//// API token admin state.

import gleam/option

import domain/api_token.{type ApiToken, type IntegrationUser}
import domain/api_token_scope
import domain/remote.{type Remote, NotAsked}
import scrumbringer_client/client_state/types as state_types

/// Form state for creating an API token.
pub type Form {
  ApiTokenForm(
    name: String,
    integration: String,
    project_id: option.Option(Int),
    scopes: List(api_token_scope.Scope),
    expires_at: String,
  )
}

/// State for the integration users and API tokens admin section.
pub type Model {
  ApiTokensModel(
    integration_users: Remote(List(IntegrationUser)),
    tokens: Remote(List(ApiToken)),
    token_dialog: state_types.DialogState(Form),
    token_rename_dialog: state_types.DialogState(#(Int, String)),
    created_token: option.Option(String),
    token_secret_copy_status: option.Option(String),
    revoke_confirm: option.Option(Int),
    integration_deactivate_confirm: option.Option(Int),
  )
}

pub fn default_token_form() -> Form {
  ApiTokenForm(
    name: "",
    integration: "",
    project_id: option.None,
    scopes: [api_token_scope.ProjectsRead, api_token_scope.TasksRead],
    expires_at: "",
  )
}

pub fn default_model() -> Model {
  ApiTokensModel(
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
