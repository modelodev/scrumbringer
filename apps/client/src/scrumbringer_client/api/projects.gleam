//// Projects API functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides project management API operations including listing, creating
//// projects, and managing project members.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/projects
////
//// projects.list_projects(ProjectsFetched)
//// projects.add_project_member(project_id, user_id, "member", MemberAdded)
//// ```

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option

import lustre/effect.{type Effect}

import scrumbringer_client/api/core.{type ApiResult}

// =============================================================================
// Types
// =============================================================================

/// A project in the organization.
pub type Project {
  Project(id: Int, name: String, my_role: String)
}

/// A member of a project with their role.
pub type ProjectMember {
  ProjectMember(user_id: Int, role: String, created_at: String)
}

// =============================================================================
// Decoders
// =============================================================================

fn project_decoder() -> decode.Decoder(Project) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use my_role <- decode.field("my_role", decode.string)
  decode.success(Project(id: id, name: name, my_role: my_role))
}

fn project_member_decoder() -> decode.Decoder(ProjectMember) {
  use user_id <- decode.field("user_id", decode.int)
  use role <- decode.field("role", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(ProjectMember(
    user_id: user_id,
    role: role,
    created_at: created_at,
  ))
}

// =============================================================================
// API Functions
// =============================================================================

/// List all projects the current user has access to.
pub fn list_projects(
  to_msg: fn(ApiResult(List(Project))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field("projects", decode.list(project_decoder()), decode.success)
  core.request("GET", "/api/v1/projects", option.None, decoder, to_msg)
}

/// Create a new project.
pub fn create_project(
  name: String,
  to_msg: fn(ApiResult(Project)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("name", json.string(name))])
  let decoder = decode.field("project", project_decoder(), decode.success)
  core.request("POST", "/api/v1/projects", option.Some(body), decoder, to_msg)
}

/// List members of a project.
pub fn list_project_members(
  project_id: Int,
  to_msg: fn(ApiResult(List(ProjectMember))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "members",
      decode.list(project_member_decoder()),
      decode.success,
    )
  core.request(
    "GET",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/members",
    option.None,
    decoder,
    to_msg,
  )
}

/// Add a member to a project.
pub fn add_project_member(
  project_id: Int,
  user_id: Int,
  role: String,
  to_msg: fn(ApiResult(ProjectMember)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([#("user_id", json.int(user_id)), #("role", json.string(role))])
  let decoder = decode.field("member", project_member_decoder(), decode.success)
  core.request(
    "POST",
    "/api/v1/projects/" <> int.to_string(project_id) <> "/members",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Remove a member from a project.
pub fn remove_project_member(
  project_id: Int,
  user_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id),
    option.None,
    to_msg,
  )
}
