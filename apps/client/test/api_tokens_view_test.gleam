import gleam/int
import gleam/option
import gleam/string
import lustre/element

import domain/api_token_scope
import domain/org_role
import domain/project.{type Project, Project}
import domain/project_role
import domain/remote
import scrumbringer_client/client_state/admin/api_tokens as api_tokens_state
import scrumbringer_client/client_state/types.{
  type ApiToken, type ApiTokensModel, type IntegrationUser, ApiToken,
  ApiTokensModel, DialogOpen, Idle, IntegrationUser,
}
import scrumbringer_client/features/admin/api_tokens_view
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  case string.contains(html, fragment) {
    True -> Nil
    False -> panic as { "expected HTML to contain: " <> fragment }
  }
}

fn assert_not_contains(html: String, fragment: String) {
  case string.contains(html, fragment) {
    False -> Nil
    True -> panic as { "expected HTML not to contain: " <> fragment }
  }
}

fn project() -> Project {
  Project(
    id: 7,
    name: "Core",
    my_role: project_role.Manager,
    created_at: "2026-01-01T10:00:00Z",
    members_count: 1,
  )
}

fn integration_user() -> IntegrationUser {
  IntegrationUser(
    id: 9,
    email: "n8n",
    org_role: org_role.Member,
    created_at: "2026-01-01T10:00:00Z",
  )
}

fn token() -> ApiToken {
  ApiToken(
    id: 11,
    org_id: 1,
    integration_user_id: 9,
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

fn model() -> ApiTokensModel {
  ApiTokensModel(
    ..api_tokens_state.default_model(),
    integration_users: remote.Loaded([integration_user()]),
    tokens: remote.Loaded([token()]),
  )
}

fn config(model: ApiTokensModel) -> api_tokens_view.Config(String) {
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
    on_token_revoke_clicked: fn(id) { "revoke:" <> int.to_string(id) },
    on_token_revoke_cancelled: "cancel-revoke",
    on_token_revoke_confirmed: "confirm-revoke",
  )
}

pub fn api_tokens_view_has_single_primary_creation_flow_test() {
  let html =
    api_tokens_view.view(config(model()))
    |> element.to_document_string

  assert_contains(html, "section admin-surface")
  assert_contains(html, "admin-surface-content")
  assert_not_contains(html, "admin-card api-token-list-card")
  assert_contains(html, "Create API token")
  assert_not_contains(html, "Create integration user")
  assert_contains(html, "n8n production")
  assert_contains(html, "n8n")
}

pub fn api_tokens_create_dialog_renders_permission_matrix_without_project_write_test() {
  let open_model =
    ApiTokensModel(
      ..model(),
      token_dialog: api_tokens_state.default_model().token_dialog,
    )
  let open_model =
    ApiTokensModel(
      ..open_model,
      token_dialog: DialogOpen(
        form: api_tokens_state.default_token_form(),
        operation: Idle,
      ),
    )

  let html =
    api_tokens_view.view(config(open_model))
    |> element.to_document_string

  assert_contains(html, "Integration")
  assert_contains(html, "Permissions")
  assert_contains(html, "Projects")
  assert_contains(html, "Read")
  assert_contains(html, "Write")
  assert_contains(html, "value=\"projects:read\"")
  assert_not_contains(html, "projects:write")
}

pub fn api_tokens_view_renders_secret_copy_control_test() {
  let with_secret =
    ApiTokensModel(
      ..model(),
      created_token: option.Some("sbt_public_secret"),
      token_secret_copy_status: option.Some("Copied"),
    )

  let html =
    api_tokens_view.view(config(with_secret))
    |> element.to_document_string

  assert_contains(html, "sbt_public_secret")
  assert_contains(html, "Copy")
  assert_contains(html, "Copied")
}
