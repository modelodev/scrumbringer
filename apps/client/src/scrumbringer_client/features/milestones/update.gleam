import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError, type ApiResult, ApiError}
import domain/milestone
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/error_codes
import scrumbringer_client/features/milestones/expansion
import scrumbringer_client/features/milestones/filters
import scrumbringer_client/features/milestones/refresh as milestone_refresh
import scrumbringer_client/features/milestones/selection
import scrumbringer_client/features/pool/msg as pool_messages

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_milestone_activated: fn(Int, ApiResult(Nil)) -> parent_msg,
    on_milestone_created: fn(ApiResult(milestone.Milestone)) -> parent_msg,
    on_milestone_updated: fn(ApiResult(milestone.Milestone)) -> parent_msg,
    on_milestone_deleted: fn(Int, ApiResult(Nil)) -> parent_msg,
    name_required: String,
    select_project_first: String,
  )
}

pub type Success {
  MilestoneActivated
  MilestoneCreated
  MilestoneUpdated
  MilestoneDeleted
}

pub type Failure {
  MilestoneActivateFailed
  MilestoneCreateFailed
  MilestoneUpdateFailed
  MilestoneDeleteFailed
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    milestone_activated: String,
    milestone_created: String,
    milestone_updated: String,
    milestone_deleted: String,
    milestone_activate_failed: String,
    milestone_create_failed: String,
    milestone_update_failed: String,
    milestone_delete_failed: String,
    milestone_already_active: String,
    milestone_activation_irreversible: String,
    milestone_delete_not_allowed: String,
    on_success_toast: fn(String) -> effect.Effect(parent_msg),
    on_error_toast: fn(String) -> effect.Effect(parent_msg),
  )
}

pub type Update(parent_msg) {
  Update(
    member_pool.Model,
    effect.Effect(parent_msg),
    RefreshPolicy,
    RootPolicy,
  )
}

pub type RefreshPolicy {
  NoRefresh
  RefreshWithSuccess(Success)
}

pub type RootPolicy {
  NoRootPolicy
  OpenCardForMilestone(Int)
}

pub fn try_member_pool_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> opt.Option(Update(parent_msg)) {
  case milestone_refresh.try_update(model, inner) {
    opt.Some(next) ->
      opt.Some(Update(next, effect.none(), NoRefresh, NoRootPolicy))
    opt.None -> try_member_pool_update_without_refresh(model, inner)
  }
}

fn try_member_pool_update_without_refresh(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberMilestonesShowCompletedToggled ->
      try_local_model_transition(model, filters.toggle_show_completed)

    pool_messages.MemberMilestonesShowEmptyToggled ->
      try_local_model_transition(model, filters.toggle_show_empty)

    pool_messages.MemberMilestoneSearchChanged(query) ->
      try_local_model_transition(model, fn(pool) {
        filters.set_search_query(pool, query)
      })

    pool_messages.MemberMilestoneSummaryToggled ->
      try_local_model_transition(model, expansion.toggle_summary)

    pool_messages.MemberMilestoneCardToggled(card_id) ->
      try_local_model_transition(model, fn(pool) {
        expansion.toggle_card(pool, card_id)
      })

    pool_messages.MemberMilestoneDetailsClicked(milestone_id) ->
      try_local_model_transition(model, fn(pool) {
        selection.select_milestone(pool, milestone_id)
      })

    _ -> opt.None
  }
}

fn try_local_model_transition(
  model: member_pool.Model,
  transition: fn(member_pool.Model) -> member_pool.Model,
) -> opt.Option(Update(parent_msg)) {
  opt.Some(Update(transition(model), effect.none(), NoRefresh, NoRootPolicy))
}

pub fn success_effect(
  success: Success,
  feedback: FeedbackContext(parent_msg),
) -> effect.Effect(parent_msg) {
  let message = case success {
    MilestoneActivated -> feedback.milestone_activated
    MilestoneCreated -> feedback.milestone_created
    MilestoneUpdated -> feedback.milestone_updated
    MilestoneDeleted -> feedback.milestone_deleted
  }

  feedback.on_success_toast(message)
}

pub fn error_effect(
  err: ApiError,
  failure: Failure,
  feedback: FeedbackContext(parent_msg),
) -> effect.Effect(parent_msg) {
  feedback.on_error_toast(error_message(err, failure, feedback))
}

pub fn error_message(
  err: ApiError,
  failure: Failure,
  feedback: FeedbackContext(parent_msg),
) -> String {
  let ApiError(code: code, message: message, ..) = err

  case error_codes.decode_error_code(code) {
    error_codes.MilestoneAlreadyActive -> feedback.milestone_already_active
    error_codes.MilestoneActivationIrreversible ->
      feedback.milestone_activation_irreversible
    error_codes.MilestoneDeleteNotAllowed ->
      feedback.milestone_delete_not_allowed
    error_codes.UnknownMilestoneErrorCode ->
      case message {
        "" -> fallback_error_message(failure, feedback)
        _ -> message
      }
  }
}

fn fallback_error_message(
  failure: Failure,
  feedback: FeedbackContext(parent_msg),
) -> String {
  case failure {
    MilestoneActivateFailed -> feedback.milestone_activate_failed
    MilestoneCreateFailed -> feedback.milestone_create_failed
    MilestoneUpdateFailed -> feedback.milestone_update_failed
    MilestoneDeleteFailed -> feedback.milestone_delete_failed
  }
}
