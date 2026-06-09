//// Admin member add dialog update handlers.
////
//// ## Mission
////
//// Handles project member add dialog flows: open/close, user selection,
//// and submission.
////
//// ## Responsibilities
////
//// - Member add dialog open/close
//// - Role dropdown changes
//// - User selection from search results
//// - Form submission and result handling
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **search.gleam**: Provides org users search for autocomplete

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/project.{type ProjectMember}
import domain/project_role.{type ProjectRole}
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages

// API modules
import scrumbringer_client/api/projects as api_projects

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    select_user_first: String,
    on_member_added: fn(ApiResult(ProjectMember)) -> parent_msg,
  )
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    member_added: String,
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
    admin_messages.MemberAddDialogOpened ->
      handle_member_add_dialog_opened(model)
      |> without_auth_check

    admin_messages.MemberAddDialogClosed ->
      handle_member_add_dialog_closed(model)
      |> without_auth_check

    admin_messages.MemberAddRoleChanged(role) ->
      handle_member_add_role_changed(model, role)
      |> without_auth_check

    admin_messages.MemberAddUserSelected(user_id) ->
      handle_member_add_user_selected(model, user_id)
      |> without_auth_check

    admin_messages.MemberAddSubmitted ->
      handle_member_add_submitted(model, context)
      |> without_auth_check

    admin_messages.MemberAdded(Ok(_)) ->
      handle_member_added_ok(model, feedback)
      |> with_refresh(RefreshSection)

    admin_messages.MemberAdded(Error(err)) ->
      handle_member_added_error(
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
// Dialog Open/Close Handlers
// =============================================================================

/// Handle member add dialog open.
pub fn handle_member_add_dialog_opened(
  model: admin_members.Model,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      members_add_dialog_mode: dialog_mode.DialogCreate,
      members_add_selected_user: opt.None,
      members_add_error: opt.None,
      org_users_search: state_types.OrgUsersSearchIdle("", 0),
    ),
    effect.none(),
  )
}

/// Handle member add dialog close.
pub fn handle_member_add_dialog_closed(
  model: admin_members.Model,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      members_add_dialog_mode: dialog_mode.DialogClosed,
      members_add_selected_user: opt.None,
      members_add_error: opt.None,
      org_users_search: state_types.OrgUsersSearchIdle("", 0),
    ),
    effect.none(),
  )
}

// =============================================================================
// Selection Handlers
// =============================================================================

/// Handle member add role dropdown change.
pub fn handle_member_add_role_changed(
  model: admin_members.Model,
  role: ProjectRole,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(admin_members.Model(..model, members_add_role: role), effect.none())
}

/// Handle member add user selection.
pub fn handle_member_add_user_selected(
  model: admin_members.Model,
  user_id: Int,
) -> #(admin_members.Model, Effect(parent_msg)) {
  let selected = case model.org_users_search {
    state_types.OrgUsersSearchLoaded(_, _, users) ->
      case list.find(users, fn(u) { u.id == user_id }) {
        Ok(user) -> opt.Some(user)
        Error(_) -> opt.None
      }

    _ -> opt.None
  }

  #(
    admin_members.Model(..model, members_add_selected_user: selected),
    effect.none(),
  )
}

// =============================================================================
// Submission Handlers
// =============================================================================

/// Handle member add form submission.
pub fn handle_member_add_submitted(
  model: admin_members.Model,
  context: Context(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  case model.members_add_in_flight {
    True -> #(model, effect.none())
    False -> {
      case context.selected_project_id, model.members_add_selected_user {
        opt.Some(project_id), opt.Some(user) -> {
          let model =
            admin_members.Model(
              ..model,
              members_add_in_flight: True,
              members_add_error: opt.None,
            )
          #(
            model,
            api_projects.add_project_member(
              project_id,
              user.id,
              model.members_add_role,
              context.on_member_added,
            ),
          )
        }

        _, _ -> #(
          admin_members.Model(
            ..model,
            members_add_error: opt.Some(context.select_user_first),
          ),
          effect.none(),
        )
      }
    }
  }
}

// =============================================================================
// Result Handlers
// =============================================================================

/// Handle member added success.
pub fn handle_member_added_ok(
  model: admin_members.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      members_add_in_flight: False,
      members_add_dialog_mode: dialog_mode.DialogClosed,
    ),
    success_effect(feedback),
  )
}

/// Handle member added error.
pub fn handle_member_added_error(
  model: admin_members.Model,
  message: String,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(
    admin_members.Model(
      ..model,
      members_add_in_flight: False,
      members_add_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn success_effect(
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  context.on_success_toast(context.member_added)
}
