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

// Import types from shared domain
import domain/project.{
  type Project, type ProjectMember, Project, ProjectMember,
}
import domain/project_role.{type ProjectRole, Manager, Member} as project_role

// =============================================================================
// Decoders
// =============================================================================

fn project_role_decoder() -> decode.Decoder(ProjectRole) {
  use role_string <- decode.then(decode.string)
  case role_string {
    "manager" -> decode.success(Manager)
    "member" -> decode.success(Member)
    _ -> decode.failure(Manager, "ProjectRole")
  }
}

fn project_decoder() -> decode.Decoder(Project) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use my_role <- decode.field("my_role", project_role_decoder())
  use created_at <- decode.field("created_at", decode.string)
  use members_count <- decode.field("members_count", decode.int)
  decode.success(Project(
    id: id,
    name: name,
    my_role: my_role,
    created_at: created_at,
    members_count: members_count,
  ))
}

fn project_member_decoder() -> decode.Decoder(ProjectMember) {
  use user_id <- decode.field("user_id", decode.int)
  use role <- decode.field("role", project_role_decoder())
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
pub fn list_projects(to_msg: fn(ApiResult(List(Project))) -> msg) -> Effect(msg) {
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
  role: ProjectRole,
  to_msg: fn(ApiResult(ProjectMember)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("user_id", json.int(user_id)),
      #("role", json.string(project_role.to_string(role))),
    ])
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

// =============================================================================
// Role Change
// =============================================================================

/// Result of a member role change operation.
pub type RoleChangeResult {
  RoleChangeResult(
    user_id: Int,
    email: String,
    role: ProjectRole,
    previous_role: ProjectRole,
  )
}

fn role_change_result_decoder() -> decode.Decoder(RoleChangeResult) {
  use user_id <- decode.field("user_id", decode.int)
  use email <- decode.field("email", decode.string)
  use role <- decode.field("role", project_role_decoder())
  use previous_role <- decode.field("previous_role", project_role_decoder())
  decode.success(RoleChangeResult(
    user_id: user_id,
    email: email,
    role: role,
    previous_role: previous_role,
  ))
}

/// Update a project member's role.
pub fn update_member_role(
  project_id: Int,
  user_id: Int,
  new_role: ProjectRole,
  to_msg: fn(ApiResult(RoleChangeResult)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([#("role", json.string(project_role.to_string(new_role)))])
  let decoder =
    decode.field("member", role_change_result_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

// =============================================================================
// Member Capabilities (Story 4.7)
// =============================================================================

/// Result of getting member capabilities.
pub type MemberCapabilities {
  MemberCapabilities(user_id: Int, capability_ids: List(Int))
}

/// Get a member's capability IDs.
pub fn get_member_capabilities(
  project_id: Int,
  user_id: Int,
  to_msg: fn(ApiResult(MemberCapabilities)) -> msg,
) -> Effect(msg) {
  let decoder = {
    use ids <- decode.field("capability_ids", decode.list(decode.int))
    decode.success(MemberCapabilities(user_id: user_id, capability_ids: ids))
  }
  core.request(
    "GET",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id)
      <> "/capabilities",
    option.None,
    decoder,
    to_msg,
  )
}

/// Set a member's capability IDs (replaces all existing).
pub fn set_member_capabilities(
  project_id: Int,
  user_id: Int,
  capability_ids: List(Int),
  to_msg: fn(ApiResult(MemberCapabilities)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("capability_ids", json.array(capability_ids, of: json.int)),
    ])
  let decoder = {
    use ids <- decode.field("capability_ids", decode.list(decode.int))
    decode.success(MemberCapabilities(user_id: user_id, capability_ids: ids))
  }
  core.request(
    "PUT",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id)
      <> "/capabilities",
    option.Some(body),
    decoder,
    to_msg,
  )
}

// =============================================================================
// Capability Members (Story 4.7 AC16-17, AC20-21)
// =============================================================================

/// Result of getting capability members.
pub type CapabilityMembers {
  CapabilityMembers(capability_id: Int, user_ids: List(Int))
}

/// Get a capability's member user IDs.
pub fn get_capability_members(
  project_id: Int,
  capability_id: Int,
  to_msg: fn(ApiResult(CapabilityMembers)) -> msg,
) -> Effect(msg) {
  let decoder = {
    use ids <- decode.field("user_ids", decode.list(decode.int))
    decode.success(CapabilityMembers(
      capability_id: capability_id,
      user_ids: ids,
    ))
  }
  core.request(
    "GET",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/capabilities/"
      <> int.to_string(capability_id)
      <> "/members",
    option.None,
    decoder,
    to_msg,
  )
}

/// Set a capability's member user IDs (replaces all existing).
pub fn set_capability_members(
  project_id: Int,
  capability_id: Int,
  user_ids: List(Int),
  to_msg: fn(ApiResult(CapabilityMembers)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([#("user_ids", json.array(user_ids, of: json.int))])
  let decoder = {
    use ids <- decode.field("user_ids", decode.list(decode.int))
    decode.success(CapabilityMembers(
      capability_id: capability_id,
      user_ids: ids,
    ))
  }
  core.request(
    "PUT",
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/capabilities/"
      <> int.to_string(capability_id)
      <> "/members",
    option.Some(body),
    decoder,
    to_msg,
  )
}

// =============================================================================
// Project CRUD (Story 4.8 AC39)
// =============================================================================

/// Update a project's name.
pub fn update_project(
  project_id: Int,
  name: String,
  to_msg: fn(ApiResult(Project)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("name", json.string(name))])
  let decoder = decode.field("project", project_decoder(), decode.success)
  core.request(
    "PATCH",
    "/api/v1/projects/" <> int.to_string(project_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Delete a project.
pub fn delete_project(
  project_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    "DELETE",
    "/api/v1/projects/" <> int.to_string(project_id),
    option.None,
    to_msg,
  )
}
