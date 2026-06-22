//// Member pool card detail state transitions.

import gleam/option as opt

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/components/card_show

pub fn handle_opened(
  model: member_pool.Model,
  card_id: Int,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    card_detail_open: opt.Some(card_id),
    card_show_model: card_show.init_model(),
  )
}

pub fn handle_closed(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    card_detail_open: opt.None,
    card_show_model: card_show.reset(),
  )
}

pub fn set_model(
  model: member_pool.Model,
  detail_model: card_show.Model,
) -> member_pool.Model {
  member_pool.Model(..model, card_show_model: detail_model)
}
