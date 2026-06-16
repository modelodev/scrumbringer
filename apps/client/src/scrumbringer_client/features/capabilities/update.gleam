//// Capabilities feature update dispatch.
////
//// ## Mission
////
//// Routes capability admin messages to focused update handlers.
////
//// ## Responsibilities
////
//// - Map admin messages to capability CRUD or assignment subflows.
//// - Attach auth policy and permission feedback to subflow results.
////
//// ## Non-responsibilities
////
//// - API calls (see `api/*.gleam`).
//// - Capability CRUD state transitions (see `crud_update.gleam`).
//// - User/capability assignment transitions (see `assignments_update.gleam`).

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/capabilities/assignments_update
import scrumbringer_client/features/capabilities/crud_update
import scrumbringer_client/features/capabilities/types as capability_types

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(admin_capabilities.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: admin_capabilities.Model,
  inner: admin_messages.Msg,
  context: capability_types.Context(parent_msg),
  feedback: capability_types.FeedbackContext(parent_msg),
  error_feedback: capability_types.ErrorFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case crud_update.try_update(model, inner, context, feedback, error_feedback) {
    opt.Some(update) -> from_child_update(update)
    opt.None ->
      assignments_update.try_update(model, inner, context, feedback)
      |> opt.map(from_child_update_value)
  }
}

fn from_child_update(
  update: #(admin_capabilities.Model, Effect(parent_msg), opt.Option(ApiError)),
) -> opt.Option(Update(parent_msg)) {
  opt.Some(from_child_update_value(update))
}

fn from_child_update_value(
  update: #(admin_capabilities.Model, Effect(parent_msg), opt.Option(ApiError)),
) -> Update(parent_msg) {
  let #(model, fx, auth_error) = update
  Update(model, fx, auth_policy(auth_error))
}

fn auth_policy(auth_error: opt.Option(ApiError)) -> AuthPolicy {
  case auth_error {
    opt.None -> NoAuthCheck
    opt.Some(err) -> CheckAuth(err)
  }
}
