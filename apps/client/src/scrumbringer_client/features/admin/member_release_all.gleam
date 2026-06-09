////
//// ## Mission
////
//// Handles releasing all claimed tasks for a project member.
////
//// ## Responsibilities
////
//// - Show release-all confirmation dialog
//// - Submit release-all request
//// - Handle result feedback
////
//// ## Relations
////
//// - **features/admin/update.gleam**: Assembles local transitions with toasts/auth
//// - **api/projects.gleam**: Release-all API call

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/project.{type ProjectMember, ProjectMember}
import domain/remote.{Loaded}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/org_user_fallback
import scrumbringer_client/helpers/lookup as helpers_lookup

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_member_release_all_result: fn(ApiResult(api_projects.ReleaseAllResult)) ->
      parent_msg,
  )
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    not_permitted: String,
    release_all_self_error: String,
    release_all_none: fn(String) -> String,
    release_all_success: fn(Int, String) -> String,
    release_all_error: fn(String) -> String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_warning_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(admin_members.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: admin_members.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.MemberReleaseAllClicked(user_id, claimed_count) ->
      handle_member_release_all_clicked(model, user_id, claimed_count)
      |> without_auth_check

    admin_messages.MemberReleaseAllCancelled ->
      handle_member_release_all_cancelled(model)
      |> without_auth_check

    admin_messages.MemberReleaseAllConfirmed ->
      handle_member_release_all_confirmed(model, context)
      |> without_auth_check

    admin_messages.MemberReleaseAllResult(Ok(result)) ->
      handle_member_release_all_ok(model, result, feedback)
      |> without_auth_check

    admin_messages.MemberReleaseAllResult(Error(err)) ->
      handle_member_release_all_error(model, err, feedback)
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(admin_members.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck)
}

fn with_auth_check(
  result: #(admin_members.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err))
}

fn with_policy(
  result: #(admin_members.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy))
}

// =============================================================================
// Confirmation Handlers
// =============================================================================

/// Handle release-all click (show confirmation).
pub fn handle_member_release_all_clicked(
  model: admin_members.Model,
  user_id: Int,
  claimed_count: Int,
) -> #(admin_members.Model, Effect(parent_msg)) {
  let maybe_user =
    helpers_lookup.resolve_org_user(model.org_users_cache, user_id)

  let user = case maybe_user {
    opt.Some(user) -> user
    opt.None -> org_user_fallback.from_id(user_id)
  }

  #(
    admin_members.Model(
      ..model,
      members_release_confirm: opt.Some(state_types.ReleaseAllTarget(
        user: user,
        claimed_count: claimed_count,
      )),
      members_release_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle release-all cancel.
pub fn handle_member_release_all_cancelled(
  model: admin_members.Model,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      members_release_confirm: opt.None,
      members_release_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle release-all confirmation.
pub fn handle_member_release_all_confirmed(
  model: admin_members.Model,
  context: Context(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  case model.members_release_in_flight {
    opt.Some(_) -> #(model, effect.none())
    opt.None ->
      case context.selected_project_id, model.members_release_confirm {
        opt.Some(project_id),
          opt.Some(state_types.ReleaseAllTarget(user: user, ..))
        -> {
          let model =
            admin_members.Model(
              ..model,
              members_release_in_flight: opt.Some(user.id),
              members_release_error: opt.None,
            )
          #(
            model,
            api_projects.release_all_member_tasks(
              project_id,
              user.id,
              context.on_member_release_all_result,
            ),
          )
        }
        _, _ -> #(model, effect.none())
      }
  }
}

// =============================================================================
// Result Handlers
// =============================================================================

/// Handle release-all success.
pub fn handle_member_release_all_ok(
  model: admin_members.Model,
  result: api_projects.ReleaseAllResult,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  let user_id = case model.members_release_confirm {
    opt.Some(state_types.ReleaseAllTarget(user: user, ..)) -> user.id
    opt.None -> 0
  }
  let user_name = release_all_target_user_name(model)

  let updated_members = case model.members {
    Loaded(members) ->
      Loaded(
        list.map(members, fn(m: ProjectMember) {
          case m.user_id == user_id {
            True -> ProjectMember(..m, claimed_count: 0)
            False -> m
          }
        }),
      )
    other -> other
  }

  #(
    admin_members.Model(
      ..model,
      members_release_confirm: opt.None,
      members_release_in_flight: opt.None,
      members_release_error: opt.None,
      members: updated_members,
    ),
    success_effect(result, user_name, feedback),
  )
}

/// Handle release-all error.
pub fn handle_member_release_all_error(
  model: admin_members.Model,
  err: ApiError,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  let message =
    error_message(err, release_all_target_user_name(model), feedback)

  #(
    admin_members.Model(
      ..model,
      members_release_in_flight: opt.None,
      members_release_error: opt.Some(message),
    ),
    feedback.on_warning_toast(message),
  )
}

pub fn release_all_target_user_name(model: admin_members.Model) -> String {
  case model.members_release_confirm {
    opt.Some(state_types.ReleaseAllTarget(user: user, ..)) -> user.email
    opt.None -> ""
  }
}

pub fn success_effect(
  result: api_projects.ReleaseAllResult,
  user_name: String,
  feedback: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  let api_projects.ReleaseAllResult(released_count: released_count, ..) = result

  case released_count == 0 {
    True -> feedback.on_warning_toast(feedback.release_all_none(user_name))
    False ->
      feedback.on_success_toast(feedback.release_all_success(
        released_count,
        user_name,
      ))
  }
}

pub fn error_message(
  err: ApiError,
  user_name: String,
  feedback: FeedbackContext(parent_msg),
) -> String {
  case err.code {
    "FORBIDDEN" -> feedback.not_permitted
    "SELF_RELEASE" -> feedback.release_all_self_error
    "NOT_FOUND" -> err.message
    _ -> feedback.release_all_error(user_name)
  }
}
