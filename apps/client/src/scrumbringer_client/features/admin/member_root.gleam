//// Shared root helpers for admin member adapters.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/route_support

pub fn set_members(
  model: client_state.Model,
  members: admin_members.Model,
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    admin_state.AdminModel(..admin, members: members)
  })
}

pub fn apply_members_result(
  model: client_state.Model,
  members: admin_members.Model,
  fx: effect.Effect(client_state.Msg),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  #(set_members(model, members), fx)
}

pub fn apply_auth_check_before(
  model: client_state.Model,
  auth_error: opt.Option(ApiError),
  apply_update: fn() -> #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  route_support.apply_auth_check_before(model, auth_error, apply_update)
}
