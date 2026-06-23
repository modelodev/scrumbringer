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

import domain/api_error.{type ApiResult}
import domain/project.{
  type Project, type ProjectDepthName, type ProjectMember, ProjectDepthName,
}
import domain/project/project_codec
import domain/project_role.{type ProjectRole}
import domain/project_role/project_role_codec
import scrumbringer_client/api/core

// =============================================================================
// API Functions
// =============================================================================

/// List all projects the current user has access to.
pub fn list_projects(to_msg: fn(ApiResult(List(Project))) -> msg) -> Effect(msg) {
  let decoder =
    decode.field(
      "projects",
      decode.list(project_codec.project_decoder()),
      decode.success,
    )
  core.request(core.Get, "/api/v1/projects", option.None, decoder, to_msg)
}

/// Create a new project.
pub fn create_project(
  name: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
  to_msg: fn(ApiResult(Project)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("healthy_pool_limit", json.int(healthy_pool_limit)),
      #(
        "card_depth_names",
        json.array(card_depth_names, of: project_depth_name_json),
      ),
    ])
  let decoder =
    decode.field("project", project_codec.project_decoder(), decode.success)
  core.request(
    core.Post,
    "/api/v1/projects",
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// List members of a project.
pub fn list_project_members(
  project_id: Int,
  to_msg: fn(ApiResult(List(ProjectMember))) -> msg,
) -> Effect(msg) {
  let decoder =
    decode.field(
      "members",
      decode.list(project_codec.project_member_decoder()),
      decode.success,
    )
  core.request(
    core.Get,
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
  let decoder =
    decode.field(
      "member",
      project_codec.project_member_decoder(),
      decode.success,
    )
  core.request(
    core.Post,
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
    core.Delete,
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

/// Result of releasing all tasks for a project member.
pub type ReleaseAllResult {
  ReleaseAllResult(released_count: Int, task_ids: List(Int))
}

pub type DepthReductionImpact {
  DepthReductionImpact(
    affected_cards_count: Int,
    available_tasks_count: Int,
    claimed_tasks_count: Int,
    blocked: Bool,
    affected_cards: List(DepthReductionAffectedCard),
  )
}

pub type DepthReductionAffectedCard {
  DepthReductionAffectedCard(id: Int, title: String, depth: Int)
}

fn release_all_result_decoder() -> decode.Decoder(ReleaseAllResult) {
  use released_count <- decode.field("released_count", decode.int)
  use task_ids <- decode.field("task_ids", decode.list(decode.int))
  decode.success(ReleaseAllResult(
    released_count: released_count,
    task_ids: task_ids,
  ))
}

fn depth_reduction_impact_decoder() -> decode.Decoder(DepthReductionImpact) {
  use affected_cards_count <- decode.field("affected_cards_count", decode.int)
  use available_tasks_count <- decode.field("available_tasks_count", decode.int)
  use claimed_tasks_count <- decode.field("claimed_tasks_count", decode.int)
  use blocked <- decode.field("blocked", decode.bool)
  use affected_cards <- decode.optional_field(
    "affected_cards",
    [],
    decode.list(depth_reduction_affected_card_decoder()),
  )
  decode.success(DepthReductionImpact(
    affected_cards_count: affected_cards_count,
    available_tasks_count: available_tasks_count,
    claimed_tasks_count: claimed_tasks_count,
    blocked: blocked,
    affected_cards: affected_cards,
  ))
}

fn depth_reduction_affected_card_decoder() -> decode.Decoder(
  DepthReductionAffectedCard,
) {
  use id <- decode.field("id", decode.int)
  use title <- decode.field("title", decode.string)
  use depth <- decode.field("depth", decode.int)
  decode.success(DepthReductionAffectedCard(id: id, title: title, depth: depth))
}

pub fn preview_depth_reduction(
  project_id: Int,
  new_max_depth: Int,
  to_msg: fn(ApiResult(DepthReductionImpact)) -> msg,
) -> Effect(msg) {
  let body = json.object([#("new_max_depth", json.int(new_max_depth))])
  core.request(
    core.Post,
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/depth-reduction-preview",
    option.Some(body),
    depth_reduction_impact_decoder(),
    to_msg,
  )
}

fn role_change_result_decoder() -> decode.Decoder(RoleChangeResult) {
  use user_id <- decode.field("user_id", decode.int)
  use email <- decode.field("email", decode.string)
  use role <- decode.field("role", project_role_codec.project_role_decoder())
  use previous_role <- decode.field(
    "previous_role",
    project_role_codec.project_role_decoder(),
  )
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
    core.Patch,
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

/// Release all claimed tasks for a project member.
pub fn release_all_member_tasks(
  project_id: Int,
  user_id: Int,
  to_msg: fn(ApiResult(ReleaseAllResult)) -> msg,
) -> Effect(msg) {
  let decoder = release_all_result_decoder()
  core.request(
    core.Post,
    "/api/v1/projects/"
      <> int.to_string(project_id)
      <> "/members/"
      <> int.to_string(user_id)
      <> "/release-all-tasks",
    option.None,
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
    core.Get,
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
    core.Put,
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
    core.Get,
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
  let body = json.object([#("user_ids", json.array(user_ids, of: json.int))])
  let decoder = {
    use ids <- decode.field("user_ids", decode.list(decode.int))
    decode.success(CapabilityMembers(
      capability_id: capability_id,
      user_ids: ids,
    ))
  }
  core.request(
    core.Put,
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
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
  to_msg: fn(ApiResult(Project)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("healthy_pool_limit", json.int(healthy_pool_limit)),
      #(
        "card_depth_names",
        json.array(card_depth_names, of: project_depth_name_json),
      ),
    ])
  let decoder =
    decode.field("project", project_codec.project_decoder(), decode.success)
  core.request(
    core.Patch,
    "/api/v1/projects/" <> int.to_string(project_id),
    option.Some(body),
    decoder,
    to_msg,
  )
}

fn project_depth_name_json(depth_name: ProjectDepthName) -> json.Json {
  let ProjectDepthName(
    depth: depth,
    singular_name: singular_name,
    plural_name: plural_name,
  ) = depth_name

  json.object([
    #("depth", json.int(depth)),
    #("singular_name", json.string(singular_name)),
    #("plural_name", json.string(plural_name)),
  ])
}

/// Delete a project.
pub fn delete_project(
  project_id: Int,
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  core.request_nil(
    core.Delete,
    "/api/v1/projects/" <> int.to_string(project_id),
    option.None,
    to_msg,
  )
}
