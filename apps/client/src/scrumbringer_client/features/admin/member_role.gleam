//// Admin project member role update handlers.

import gleam/list
import gleam/option as opt
import gleam/result

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/project.{type ProjectMember, ProjectMember}
import domain/project_role.{type ProjectRole}
import domain/remote.{Loaded}
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/ui/toast

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_member_role_changed: fn(ApiResult(api_projects.RoleChangeResult)) ->
      parent_msg,
  )
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    role_updated: String,
    cannot_demote_last_manager: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_warning_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
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
    admin_messages.MemberRoleChangeRequested(user_id, new_role) ->
      handle_member_role_change_requested(model, user_id, new_role, context)
      |> without_auth_check

    admin_messages.MemberRoleChanged(Ok(result)) ->
      handle_member_role_changed_ok(model, result, feedback)
      |> without_auth_check

    admin_messages.MemberRoleChanged(Error(err)) ->
      #(model, error_effect(err, feedback))
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

pub fn input_value(value: String) -> Result(ProjectRole, Nil) {
  project_role.parse(value)
  |> result.replace_error(Nil)
}

pub fn changed_input_value(
  value: String,
  current: ProjectRole,
) -> Result(ProjectRole, Nil) {
  case input_value(value) {
    Ok(role) if role != current -> Ok(role)
    _ -> Error(Nil)
  }
}

pub fn handle_member_role_change_requested(
  model: admin_members.Model,
  user_id: Int,
  new_role: ProjectRole,
  context: Context(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  case context.selected_project_id {
    opt.Some(project_id) -> #(
      model,
      api_projects.update_member_role(
        project_id,
        user_id,
        new_role,
        context.on_member_role_changed,
      ),
    )
    opt.None -> #(model, effect.none())
  }
}

pub fn handle_member_role_changed_ok(
  model: admin_members.Model,
  result: api_projects.RoleChangeResult,
  context: FeedbackContext(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  let updated_members = case model.members {
    Loaded(members) ->
      Loaded(
        list.map(members, fn(m: ProjectMember) {
          case m.user_id == result.user_id {
            True -> ProjectMember(..m, role: result.role)
            False -> m
          }
        }),
      )
    other -> other
  }

  #(
    admin_members.Model(..model, members: updated_members),
    success_effect(context),
  )
}

pub fn success_effect(
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  context.on_success_toast(context.role_updated)
}

pub fn error_effect(
  err: ApiError,
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  let #(message, variant) =
    error_feedback(err, context.cannot_demote_last_manager)

  case variant {
    toast.Warning -> context.on_warning_toast(message)
    toast.Error -> context.on_error_toast(message)
    _ -> context.on_error_toast(message)
  }
}

pub fn error_feedback(
  err: ApiError,
  cannot_demote_last_manager: String,
) -> #(String, toast.ToastVariant) {
  case err.status {
    422 -> #(cannot_demote_last_manager, toast.Warning)
    _ -> #(err.message, toast.Error)
  }
}
