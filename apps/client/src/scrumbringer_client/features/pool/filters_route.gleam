//// Root-aware adapter for member-pool filter updates.

import gleam/option as opt
import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/features/pool/filters
import scrumbringer_client/features/pool/root

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
  member_refresh: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case filters.try_update(model.member.pool, inner) {
    opt.Some(#(pool, should_refresh)) -> {
      let next = root.set_member_pool(model, pool)
      case should_refresh {
        True -> opt.Some(member_refresh(next))
        False -> opt.Some(#(next, effect.none()))
      }
    }
    opt.None -> opt.None
  }
}
