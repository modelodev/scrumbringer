import gleam/dict
import gleam/option as opt

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/milestones/expansion

pub fn milestones_expansion_toggle_summary_test() {
  let model = member_pool.default_model()

  let expanded = expansion.toggle_summary(model)
  let collapsed = expansion.toggle_summary(expanded)

  let assert True = expanded.member_milestone_summary_expanded
  let assert False = collapsed.member_milestone_summary_expanded
}

pub fn milestones_expansion_toggle_card_adds_and_removes_card_test() {
  let model = member_pool.default_model()

  let expanded = expansion.toggle_card(model, 401)
  let collapsed = expansion.toggle_card(expanded, 401)

  let assert Ok(True) = dict.get(expanded.member_milestone_expanded_cards, 401)
  let assert Error(_) = dict.get(collapsed.member_milestone_expanded_cards, 401)
}

pub fn milestones_expansion_toggle_card_keeps_other_cards_test() {
  let model =
    member_pool.Model(
      ..member_pool.default_model(),
      member_milestone_expanded_cards: dict.from_list([
        #(1, True),
        #(2, True),
      ]),
    )

  let next = expansion.toggle_card(model, 1)

  let assert Error(_) = dict.get(next.member_milestone_expanded_cards, 1)
  let assert opt.Some(True) =
    dict.get(next.member_milestone_expanded_cards, 2)
    |> opt.from_result
}
