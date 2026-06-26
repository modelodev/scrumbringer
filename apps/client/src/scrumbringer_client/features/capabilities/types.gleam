//// Shared contracts for capability update subflows.

import lustre/effect.{type Effect}

import gleam/option.{type Option}

import domain/api_error.{type ApiResult}
import domain/capability.{type Capability}
import scrumbringer_client/api/member_capabilities
import scrumbringer_client/api/projects as api_projects

pub type Context(parent_msg) {
  Context(
    selected_project_id: Option(Int),
    on_member_capabilities_fetched: fn(
      ApiResult(member_capabilities.MemberCapabilities),
    ) ->
      parent_msg,
    on_member_capabilities_saved: fn(
      ApiResult(member_capabilities.MemberCapabilities),
    ) ->
      parent_msg,
    on_capability_members_fetched: fn(ApiResult(api_projects.CapabilityMembers)) ->
      parent_msg,
    on_capability_members_saved: fn(ApiResult(api_projects.CapabilityMembers)) ->
      parent_msg,
    on_capability_created: fn(ApiResult(Capability)) -> parent_msg,
    on_capability_updated: fn(ApiResult(Capability)) -> parent_msg,
    on_capability_deleted: fn(ApiResult(Int)) -> parent_msg,
    name_required: String,
  )
}

pub type Success {
  CapabilityCreated
  CapabilityUpdated
  CapabilityDeleted
  MemberCapabilitiesSaved
  CapabilityMembersSaved
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    capability_created: String,
    capability_updated: String,
    capability_deleted: String,
    member_capabilities_saved: String,
    capability_members_saved: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorFeedbackContext(parent_msg) {
  ErrorFeedbackContext(
    not_permitted: String,
    on_warning_toast: fn(String) -> Effect(parent_msg),
  )
}

pub fn success_effect(
  success: Success,
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  context.on_success_toast(success_message(success, context))
}

fn success_message(success: Success, context: FeedbackContext(parent_msg)) {
  case success {
    CapabilityCreated -> context.capability_created
    CapabilityUpdated -> context.capability_updated
    CapabilityDeleted -> context.capability_deleted
    MemberCapabilitiesSaved -> context.member_capabilities_saved
    CapabilityMembersSaved -> context.capability_members_saved
  }
}
