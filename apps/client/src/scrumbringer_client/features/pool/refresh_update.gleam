//// Root-aware adapters for member pool refresh results.

import gleam/option as opt
import lustre/effect

import domain/api_error.{type ApiError}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/card_refresh
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/position_layout
import scrumbringer_client/features/pool/project_refresh
import scrumbringer_client/features/route_support

pub fn try_project_update(
  model: client_state.Model,
  inner: pool_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case project_refresh.try_update(model.member.pool, inner) {
    opt.Some(update) -> opt.Some(apply_project_update(model, update))
    opt.None -> opt.None
  }
}

pub fn try_card_update(
  model: client_state.Model,
  inner: pool_messages.Msg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case card_refresh.try_update(model.member.pool, inner) {
    opt.Some(pool) ->
      opt.Some(#(update_member_pool(model, fn(_) { pool }), effect.none()))
    opt.None -> opt.None
  }
}

fn apply_project_update(
  model: client_state.Model,
  update: project_refresh.Update,
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let project_refresh.Update(pool, auth_policy) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(project_refresh_auth_error(auth_policy)),
    fn() {
      let model = update_member_pool(model, fn(_) { pool })
      #(position_layout.compact_loaded_pool_positions(model), effect.none())
    },
  )
}

fn project_refresh_auth_error(
  policy: project_refresh.AuthPolicy,
) -> opt.Option(ApiError) {
  case policy {
    project_refresh.NoAuthCheck -> opt.None
    project_refresh.CheckAuth(err) -> opt.Some(err)
  }
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
