//// Root-aware adapter for admin org-user search updates.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/features/admin/member_root
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/search

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case search.try_update(model.admin.members, inner, context()) {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

fn context() -> search.Context(client_state.Msg) {
  search.Context(on_search_results: fn(token, result) {
    client_state.admin_msg(admin_messages.OrgUsersSearchResults(token, result))
  })
}

fn apply_update(
  model: client_state.Model,
  update: search.Update(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let search.Update(members, local_fx, auth_policy) = update

  member_root.apply_auth_check_before(model, auth_error(auth_policy), fn() {
    member_root.apply_members_result(model, members, local_fx)
  })
}

fn auth_error(policy: search.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    search.NoAuthCheck -> opt.None
    search.CheckAuth(err) -> opt.Some(err)
  }
}
