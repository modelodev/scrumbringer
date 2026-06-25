//// Root-aware adapter for admin member-list updates.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/member_list
import scrumbringer_client/features/admin/member_root
import scrumbringer_client/features/admin/msg as admin_messages

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case member_list.try_update(model.admin.members, inner, context(model)) {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn context(model: client_state.Model) -> member_list.Context(client_state.Msg) {
  member_list.Context(
    selected_project_id: model.core.selected_project_id,
    on_member_capabilities_fetched: fn(result) {
      client_state.admin_msg(admin_messages.MemberCapabilitiesFetched(result))
    },
  )
}

fn apply_update(
  model: client_state.Model,
  update: member_list.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let member_list.Update(members, local_fx, auth_policy) = update

  member_root.apply_auth_check(
    model,
    member_root.auth_check_before(auth_error(auth_policy)),
    fn() { member_root.apply_members_result(model, members, local_fx) },
  )
}

fn auth_error(policy: member_list.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    member_list.NoAuthCheck -> opt.None
    member_list.CheckAuth(err) -> opt.Some(err)
  }
}
