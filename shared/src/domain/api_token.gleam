//// Public API token contract types.
////
//// These records describe the metadata exposed to the client. Bearer secrets
//// and verification-only fields remain server-internal.

import domain/api_token_scope
import domain/org_role.{type OrgRole}
import gleam/option.{type Option, None, Some}

/// User identity used by external systems through API tokens.
pub type IntegrationUser {
  IntegrationUser(
    id: Int,
    email: String,
    org_role: OrgRole,
    created_at: String,
    active_token_count: Int,
  )
}

/// API token metadata. The bearer secret is only returned at creation time.
pub type ApiToken {
  ApiToken(
    id: Int,
    org_id: Int,
    integration_user_id: Int,
    integration_user_email: String,
    project_id: Option(Int),
    name: String,
    public_id: String,
    scopes: List(api_token_scope.Scope),
    created_at: String,
    last_used_at: Option(String),
    expires_at: Option(String),
    revoked_at: Option(String),
    expired: Bool,
  )
}

/// Response produced when a token is created.
pub type CreatedApiToken {
  CreatedApiToken(api_token: ApiToken, token: String)
}

/// Project scope granted to an API token.
///
/// `None` in the public JSON contract means all projects; a concrete
/// `project_id` means the token is restricted to that project.
pub type ProjectGrant {
  AllProjects
  ProjectOnly(Int)
}

pub fn project_grant_from_option(project_id: Option(Int)) -> ProjectGrant {
  case project_id {
    None -> AllProjects
    Some(project_id) -> ProjectOnly(project_id)
  }
}

pub fn project_grant_to_option(project_grant: ProjectGrant) -> Option(Int) {
  case project_grant {
    AllProjects -> None
    ProjectOnly(project_id) -> Some(project_id)
  }
}
