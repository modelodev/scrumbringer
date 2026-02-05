//// My Bar feature update handlers.
////
//// View-only feature for now (Phase 1 modularization).

import lustre/effect.{type Effect}

import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/features/my_bar/msg as my_bar_msg

/// No-op update for My Bar feature.
pub fn update(model: Model, _msg: my_bar_msg.Msg) -> #(Model, Effect(Msg)) {
  #(model, effect.none())
}
