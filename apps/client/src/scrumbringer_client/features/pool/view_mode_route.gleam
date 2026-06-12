//// Root route effects for member pool view-mode transitions.

import gleam/option as opt
import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/view_mode_update
import scrumbringer_client/router

pub fn try_update(
  model: client_state.Model,
  inner: pool_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case view_mode_update.try_update(model.member.pool, inner, context(model)) {
    opt.Some(update) -> opt.Some(apply_update(model, update))
    opt.None -> opt.None
  }
}

pub fn apply(
  route_policy: view_mode_update.RoutePolicy,
) -> effect.Effect(client_state.Msg) {
  case route_policy {
    view_mode_update.NoRouteChange -> effect.none()
    view_mode_update.ReplaceMemberRoute(state) ->
      router.replace(router.Member(state))
  }
}

fn context(model: client_state.Model) -> view_mode_update.Context {
  view_mode_update.Context(selected_project_id: model.core.selected_project_id)
}

fn apply_update(
  model: client_state.Model,
  update: view_mode_update.Update,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let view_mode_update.Update(pool, route_policy) = update
  let model = update_member_pool(model, fn(_) { pool })

  #(model, apply(route_policy))
}

fn update_member_pool(
  model: client_state.Model,
  f: fn(member_pool.Model) -> member_pool.Model,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(..member, pool: f(pool))
  })
}
