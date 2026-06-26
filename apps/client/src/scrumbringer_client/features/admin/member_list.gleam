//// Project member list update flow.

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/project.{type ProjectMember}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/member_capabilities
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_member_capabilities_fetched: fn(
      ApiResult(member_capabilities.MemberCapabilities),
    ) ->
      parent_msg,
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
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.MembersFetched(Ok(members)) ->
      handle_members_fetched_ok(model, members, context)
      |> without_auth_check

    admin_messages.MembersFetched(Error(err)) ->
      handle_members_fetched_error(model, err)
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

fn handle_members_fetched_ok(
  model: admin_members.Model,
  members: List(ProjectMember),
  context: Context(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  let preload_fx = case context.selected_project_id {
    opt.Some(project_id) ->
      members
      |> list.map(fn(member) {
        member_capabilities.get_member_capabilities(
          project_id,
          member.user_id,
          context.on_member_capabilities_fetched,
        )
      })
      |> effect.batch

    opt.None -> effect.none()
  }

  #(admin_members.Model(..model, members: Loaded(members)), preload_fx)
}

fn handle_members_fetched_error(
  model: admin_members.Model,
  err: ApiError,
) -> #(admin_members.Model, Effect(parent_msg)) {
  #(admin_members.Model(..model, members: Failed(err)), effect.none())
}
