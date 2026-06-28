import gleam/int
import gleam/option
import support/domain_fixtures
import support/render_assertions

import domain/api_token.{
  type ApiToken, type IntegrationUser, ApiToken, IntegrationUser,
}
import domain/api_token_scope
import domain/org_role
import domain/project.{type Project}
import domain/remote
import scrumbringer_client/client_state/admin/api_tokens as api_tokens_state
import scrumbringer_client/client_state/types.{DialogOpen, Idle}
import scrumbringer_client/features/admin/api_tokens_view
import scrumbringer_client/i18n/locale

fn project() -> Project {
  domain_fixtures.project(7, "Core")
}

fn integration_user() -> IntegrationUser {
  IntegrationUser(
    id: 9,
    email: "n8n",
    org_role: org_role.Member,
    created_at: "2026-01-01T10:00:00Z",
    active_token_count: 1,
  )
}

fn token() -> ApiToken {
  ApiToken(
    id: 11,
    org_id: 1,
    integration_user_id: 9,
    integration_user_email: "n8n",
    project_id: option.Some(7),
    name: "n8n production",
    public_id: "pub",
    scopes: [
      api_token_scope.ProjectsRead,
      api_token_scope.TasksWrite,
    ],
    created_at: "2026-01-01T10:00:00Z",
    last_used_at: option.None,
    expires_at: option.None,
    revoked_at: option.None,
    expired: False,
  )
}

fn model() -> api_tokens_state.Model {
  api_tokens_state.ApiTokensModel(
    ..api_tokens_state.default_model(),
    integration_users: remote.Loaded([integration_user()]),
    tokens: remote.Loaded([token()]),
  )
}

fn config(model: api_tokens_state.Model) -> api_tokens_view.Config(String) {
  api_tokens_view.Config(
    locale: locale.En,
    model: model,
    projects: [project()],
    on_token_create_opened: "open-token",
    on_token_create_closed: "close-token",
    on_token_name_changed: fn(value) { "name:" <> value },
    on_token_integration_changed: fn(value) { "integration:" <> value },
    on_token_project_changed: fn(value) { "project:" <> value },
    on_token_scope_toggled: fn(value) {
      "scope:" <> api_token_scope.to_string(value)
    },
    on_token_expires_at_changed: fn(value) { "expires:" <> value },
    on_token_create_submitted: "submit-token",
    on_token_secret_dismissed: "dismiss-secret",
    on_token_secret_copy_clicked: fn(value) { "copy:" <> value },
    on_token_rename_clicked: fn(id, name) {
      "rename:" <> int.to_string(id) <> ":" <> name
    },
    on_token_rename_cancelled: "cancel-rename",
    on_token_rename_name_changed: fn(value) { "rename-name:" <> value },
    on_token_rename_submitted: "submit-rename",
    on_token_revoke_clicked: fn(id) { "revoke:" <> int.to_string(id) },
    on_token_revoke_cancelled: "cancel-revoke",
    on_token_revoke_confirmed: "confirm-revoke",
    on_integration_deactivate_clicked: fn(id) {
      "deactivate:" <> int.to_string(id)
    },
    on_integration_deactivate_cancelled: "cancel-deactivate",
    on_integration_deactivate_confirmed: "confirm-deactivate",
  )
}

pub fn api_tokens_view_has_single_primary_creation_flow_test() {
  let html =
    api_tokens_view.view(config(model()))
    |> render_assertions.html

  render_assertions.contains(html, "section admin-surface")
  render_assertions.contains(html, "admin-surface-content")
  render_assertions.not_contains(html, "admin-card api-token-list-card")
  render_assertions.contains(html, "Create API token")
  render_assertions.contains(html, "btn-primary")
  render_assertions.contains(html, "btn-global-action")
  render_assertions.contains(html, "btn-icon-text")
  render_assertions.not_contains(html, "class=\"btn btn-primary\"")
  render_assertions.not_contains(html, "Create integration user")
  render_assertions.contains(html, "n8n production")
  render_assertions.contains(html, "n8n")
  render_assertions.contains(html, "Integrations")
  render_assertions.contains(html, "Active tokens")
  render_assertions.contains(html, "Rename API token")
}

pub fn api_tokens_create_dialog_renders_permission_matrix_without_project_write_test() {
  let open_model =
    api_tokens_state.ApiTokensModel(
      ..model(),
      token_dialog: api_tokens_state.default_model().token_dialog,
    )
  let open_model =
    api_tokens_state.ApiTokensModel(
      ..open_model,
      token_dialog: DialogOpen(
        form: api_tokens_state.default_token_form(),
        operation: Idle,
      ),
    )

  let html =
    api_tokens_view.view(config(open_model))
    |> render_assertions.html

  render_assertions.contains(html, "Integration")
  render_assertions.contains(html, "Permissions")
  render_assertions.contains(html, "Projects")
  render_assertions.contains(html, "Read")
  render_assertions.contains(html, "Write")
  render_assertions.contains(html, "value=\"projects:read\"")
  render_assertions.not_contains(html, "projects:write")
}

pub fn api_tokens_view_renders_secret_copy_control_test() {
  let with_secret =
    api_tokens_state.ApiTokensModel(
      ..model(),
      created_token: option.Some("sbt_public_secret"),
      token_secret_copy_status: option.Some("Copied"),
    )

  let html =
    api_tokens_view.view(config(with_secret))
    |> render_assertions.html

  render_assertions.contains(html, "sbt_public_secret")
  render_assertions.contains(html, "Copy")
  render_assertions.contains(html, "Copied")
  render_assertions.contains(html, "Dismiss")
  render_assertions.contains(html, "btn-secondary")
  render_assertions.contains(html, "btn-entity-action")
  render_assertions.not_contains(html, "class=\"btn-secondary\"")
}

pub fn api_tokens_view_shows_deactivate_only_for_idle_integrations_test() {
  let idle_user =
    IntegrationUser(
      ..integration_user(),
      id: 10,
      email: "zapier",
      active_token_count: 0,
    )
  let model =
    api_tokens_state.ApiTokensModel(
      ..model(),
      integration_users: remote.Loaded([integration_user(), idle_user]),
    )

  let html =
    api_tokens_view.view(config(model))
    |> render_assertions.html

  render_assertions.contains(html, "zapier")
  render_assertions.contains(html, "Deactivate integration")
}

pub fn api_tokens_view_hides_revoke_action_for_revoked_tokens_test() {
  let revoked_token =
    ApiToken(..token(), revoked_at: option.Some("2026-01-02T10:00:00Z"))
  let model =
    api_tokens_state.ApiTokensModel(
      ..model(),
      tokens: remote.Loaded([revoked_token]),
    )

  let html =
    api_tokens_view.view(config(model))
    |> render_assertions.html

  render_assertions.contains(html, "Revoked")
  render_assertions.contains(html, "Rename API token")
  render_assertions.not_contains(html, "Revoke API token")
}
