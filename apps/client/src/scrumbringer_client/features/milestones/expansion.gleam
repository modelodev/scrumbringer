//// Milestone local expansion state transitions.

import gleam/dict
import gleam/option as opt

import scrumbringer_client/client_state/member/pool as member_pool

pub fn toggle_summary(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_milestone_summary_expanded: !model.member_milestone_summary_expanded,
  )
}

pub fn toggle_card(model: member_pool.Model, card_id: Int) -> member_pool.Model {
  let current =
    dict.get(model.member_milestone_expanded_cards, card_id)
    |> opt.from_result
    |> card_expanded_or_default
  let next_expanded_cards = case current {
    True -> dict.delete(model.member_milestone_expanded_cards, card_id)
    False -> dict.insert(model.member_milestone_expanded_cards, card_id, True)
  }

  member_pool.Model(
    ..model,
    member_milestone_expanded_cards: next_expanded_cards,
  )
}

fn card_expanded_or_default(expanded: opt.Option(Bool)) -> Bool {
  case expanded {
    opt.None -> False
    opt.Some(value) -> value
  }
}
