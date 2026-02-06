//// Organization API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides organization management API operations including users,
//// capabilities, invites, and invite links.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/org
////
//// org.list_org_users("", UsersFetched)
//// org.list_capabilities(CapabilitiesFetched)
//// org.create_invite_link("user@example.com", LinkCreated)
//// ```

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/client_ffi

// Import types from shared domain
import domain/capability.{type Capability}
import domain/capability/codec as capability_codec
import domain/org.{type InviteLink, type OrgInvite, type OrgUser}
import domain/org/codec as org_codec
import domain/org_role

/// Decoder for invite link wrapped in envelope.
pub fn invite_link_payload_decoder() -> decode.Decoder(InviteLink) {
  decode.field("invite_link", org_codec.invite_link_decoder(), decode.success)
}

/// Decoder for list of invite links.
pub fn invite_links_payload_decoder() -> decode.Decoder(List(InviteLink)) {
  decode.field(
    "invite_links",
    decode.list(org_codec.invite_link_decoder()),
    decode.success,
  )
}

// =============================================================================
// User API Functions
// =============================================================================

/// List organization users, optionally filtered by query.
pub fn list_org_users(
  query: String,
  to_msg: fn(ApiResult(List(OrgUser))) -> msg,
) -> Effect(msg) {
  let q = string.trim(query)

  let url = case q == "" {
    True -> "/api/v1/org/users"
    False -> "/api/v1/org/users?q=" <> client_ffi.encode_uri_component(q)
  }

  let decoder =
    decode.field(
      "users",
      decode.list(org_codec.org_user_decoder()),
      decode.success,
    )
  core.request("GET", url, option.None, decoder, to_msg)
}

/// Update an organization user's role.
pub fn update_org_user_role(
  user_id: Int,
  role: org_role.OrgRole,
  to_msg: fn(ApiResult(OrgUser)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("org_role", json.string(org_role.to_string(role)))])

  let decoder =
    decode.field("user", org_codec.org_user_decoder(), decode.success)

  core.request(
    "PATCH",
    "/api/v1/org/users/" <> int.to_string(user_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Delete an organization user.
pub fn delete_org_user(
  user_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/org/users/" <> int.to_string(user_id),
    option.None,
    to_msg,
  )
}

// =============================================================================
// User Projects API Functions
// =============================================================================

import domain/project.{type Project}
import domain/project/codec as project_codec

/// List projects that a user is a member of.
pub fn list_user_projects(
  user_id: Int,
  to_msg: fn(ApiResult(List(Project))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "projects",
      decode.list(project_codec.user_project_decoder()),
      decode.success,
    )
  core.request(
    "GET",
    "/api/v1/org/users/" <> int.to_string(user_id) <> "/projects",
    option.None,
    decoder,
    to_msg,
  )
}

/// Add a user to a project with a role.
pub fn add_user_to_project(
  user_id: Int,
  project_id: Int,
  role: String,
  to_msg: fn(ApiResult(Project)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("project_id", json.int(project_id)),
      #("role", json.string(role)),
    ])
  let decoder =
    decode.field(
      "project",
      project_codec.user_project_decoder(),
      decode.success,
    )
  core.request(
    "POST",
    "/api/v1/org/users/" <> int.to_string(user_id) <> "/projects",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Update a user's role in a project.
pub fn update_user_project_role(
  user_id: Int,
  project_id: Int,
  role: String,
  to_msg: fn(ApiResult(Project)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("role", json.string(role))])
  let decoder =
    decode.field(
      "project",
      project_codec.user_project_decoder(),
      decode.success,
    )
  core.request(
    "PATCH",
    "/api/v1/org/users/"
      <> int.to_string(user_id)
      <> "/projects/"
      <> int.to_string(project_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Remove a user from a project.
pub fn remove_user_from_project(
  user_id: Int,
  project_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/org/users/"
      <> int.to_string(user_id)
      <> "/projects/"
      <> int.to_string(project_id),
    option.None,
    to_msg,
  )
}

// =============================================================================
// Capability API Functions (Project-Scoped)
// =============================================================================

/// List capabilities for a project.
pub fn list_project_capabilities(
  project_id: Int,
  to_msg: fn(ApiResult(List(Capability))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "capabilities",
      decode.list(capability_codec.capability_decoder()),
      decode.success,
    )
  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    option.None,
    decoder,
    to_msg,
  )
}

/// Create a capability in a project.
pub fn create_project_capability(
  project_id: Int,
  name: String,
  to_msg: fn(ApiResult(Capability)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("name", json.string(name))])
  let decoder =
    decode.field(
      "capability",
      capability_codec.capability_decoder(),
      decode.success,
    )
  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/capabilities",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Delete a capability from a project (Story 4.9 AC9).
pub fn delete_project_capability(
  project_id: Int,
  capability_id: Int,
  to_msg: fn(ApiResult(Int)) -> msg,
) -> Effect(msg) {
  let decoder = decode.field("id", decode.int, decode.success)
  core.request(
    "DELETE",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/capabilities/"
      <> int.to_string(capability_id),
    option.None,
    decoder,
    to_msg,
  )
}

// =============================================================================
// Invite API Functions
// =============================================================================

/// Create an organization invite code.
pub fn create_invite(
  expires_in_hours: option.Option(Int),
  to_msg: fn(ApiResult(OrgInvite)) -> msg,
) -> Effect(msg) {
  let body =
    json.object(case expires_in_hours {
      option.Some(hours) -> [#("expires_in_hours", json.int(hours))]
      option.None -> []
    })

  let decoder =
    decode.field("invite", org_codec.invite_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/org/invites",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// List all invite links.
pub fn list_invite_links(
  to_msg: fn(ApiResult(List(InviteLink))) -> msg,
) -> Effect(msg) {
  core.request(
    "GET",
    "/api/v1/org/invite-links",
    option.None,
    invite_links_payload_decoder(),
    to_msg,
  )
}

/// Create an invite link for an email.
pub fn create_invite_link(
  email: String,
  to_msg: fn(ApiResult(InviteLink)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("email", json.string(string.trim(email)))])
  core.request(
    "POST",
    "/api/v1/org/invite-links",
    option.Some(body),
    invite_link_payload_decoder(),
    to_msg,
  )
}

/// Regenerate an invite link for an email.
pub fn regenerate_invite_link(
  email: String,
  to_msg: fn(ApiResult(InviteLink)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("email", json.string(string.trim(email)))])
  core.request(
    "POST",
    "/api/v1/org/invite-links/regenerate",
    option.Some(body),
    invite_link_payload_decoder(),
    to_msg,
  )
}
