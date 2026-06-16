//// Admin member remove update handlers.
////
//// Handles the local state for project member removal. The admin coordinator
//// owns auth handling, refreshes and toast presentation.

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/org_user_fallback
import scrumbringer_client/helpers/lookup as helpers_lookup

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_member_removed: fn(ApiResult(Nil)) -> parent_msg,
  )
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    member_removed: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorFeedbackContext(parent_msg) {
  ErrorFeedbackContext(
    not_permitted: String,
    on_warning_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type RefreshPolicy {
  NoRefresh
  RefreshSection
}

pub type Update(parent_msg) {
  Update(admin_members.Model, Effect(parent_msg), AuthPolicy, RefreshPolicy)
}

pub fn try_update(
  model: admin_members.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
  error_feedback: ErrorFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.MemberRemoveClicked(user_id) ->
      handle_member_remove_clicked(model, user_id)
      |> without_auth_check

    admin_messages.MemberRemoveCancelled ->
      handle_member_remove_cancelled(model)
      |> without_auth_check

    admin_messages.MemberRemoveConfirmed ->
      handle_member_remove_confirmed(model, context)
      |> without_auth_check

    admin_messages.MemberRemoved(Ok(_)) ->
      handle_member_removed_ok(model, feedback)
      |> with_refresh(RefreshSection)

    admin_messages.MemberRemoved(Error(err)) ->
      handle_member_removed_error(
        model,
        permission_error_message(err, error_feedback),
      )
      |> with_auth_check_and_effect(
        err,
        permission_warning_effect(err, error_feedback),
      )

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(admin_members.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck, NoRefresh)
}

fn with_auth_check_and_effect(
  result: #(admin_members.Model, Effect(parent_msg)),
  err: ApiError,
  extra_fx: Effect(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(
    model,
    effect.batch([fx, extra_fx]),
    CheckAuth(err),
    NoRefresh,
  ))
}

fn with_refresh(
  result: #(admin_members.Model, Effect(parent_msg)),
  refresh_policy: RefreshPolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck, refresh_policy)
}

fn with_policy(
  result: #(admin_members.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
  refresh_policy: RefreshPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy, refresh_policy))
}

fn permission_error_message(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> String {
  case err.status {
    403 -> feedback.not_permitted
    _ -> err.message
  }
}

fn permission_warning_effect(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(feedback.not_permitted)
    _ -> effect.none()
  }
}

// =============================================================================
// Confirmation Handlers
// =============================================================================

fn handle_member_remove_clicked(
  model: admin_members.Model,
  user_id: Int,
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
      members_remove_confirm: opt.Some(user),
      members_remove_error: opt.None,
    ),
    effect.none(),
  )
}

fn handle_member_remove_cancelled(
  model: admin_members.Model,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      members_remove_confirm: opt.None,
      members_remove_error: opt.None,
    ),
    effect.none(),
  )
}

fn handle_member_remove_confirmed(
  model: admin_members.Model,
  context: Context(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  case model.members_remove_in_flight {
    True -> #(model, effect.none())
    False ->
      case context.selected_project_id, model.members_remove_confirm {
        opt.Some(project_id), opt.Some(user) -> {
          let model =
            admin_members.Model(
              ..model,
              members_remove_in_flight: True,
              members_remove_error: opt.None,
            )
          #(
            model,
            api_projects.remove_project_member(
              project_id,
              user.id,
              context.on_member_removed,
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

fn handle_member_removed_ok(
  model: admin_members.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      members_remove_in_flight: False,
      members_remove_confirm: opt.None,
      members_remove_error: opt.None,
    ),
    success_effect(feedback),
  )
}

fn handle_member_removed_error(
  model: admin_members.Model,
  message: String,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      members_remove_in_flight: False,
      members_remove_error: opt.Some(message),
    ),
    effect.none(),
  )
}

fn success_effect(context: FeedbackContext(parent_msg)) -> Effect(parent_msg) {
  context.on_success_toast(context.member_removed)
}
