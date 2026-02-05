//// Fichas feature update handlers.
////
//// View-only feature for now (Phase 1 modularization).

import lustre/effect.{type Effect}

import scrumbringer_client/client_state.{type Model, type Msg}
import scrumbringer_client/features/fichas/msg as fichas_msg

/// No-op update for Fichas feature.
pub fn update(model: Model, _msg: fichas_msg.Msg) -> #(Model, Effect(Msg)) {
  #(model, effect.none())
}
