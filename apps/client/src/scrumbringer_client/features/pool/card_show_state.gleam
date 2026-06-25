//// Member pool card show state transitions.

import gleam/option as opt

import scrumbringer_client/features/cards/show as card_show

pub fn handle_opened(card_id: Int) -> #(opt.Option(Int), card_show.Model) {
  #(opt.Some(card_id), card_show.init_model())
}

pub fn handle_closed() -> #(opt.Option(Int), card_show.Model) {
  #(opt.None, card_show.reset())
}

pub fn set_model(show_model: card_show.Model) -> card_show.Model {
  show_model
}
