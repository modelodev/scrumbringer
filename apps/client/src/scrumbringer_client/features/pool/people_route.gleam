//// Root-aware adapter for member-pool people updates.

import gleam/option as opt
import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/features/people/update as people_workflow
import scrumbringer_client/features/pool/root

pub fn try_update(
  model: client_state.Model,
  inner: client_state.PoolMsg,
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case people_workflow.try_update(model.member.pool, inner) {
    opt.Some(#(pool, fx)) -> opt.Some(#(root.set_member_pool(model, pool), fx))
    opt.None -> opt.None
  }
}
