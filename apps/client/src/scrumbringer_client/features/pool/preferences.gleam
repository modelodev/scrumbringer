//// Member pool display preferences.

import gleam/dict
import gleam/option as opt

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/pool_prefs

pub type Persistence {
  NoPersistence
  SaveViewMode(pool_prefs.ViewMode)
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
) -> opt.Option(#(member_pool.Model, Persistence)) {
  case inner {
    pool_messages.MemberPoolViewModeSet(mode) ->
      opt.Some(#(handle_view_mode_set(model, mode), SaveViewMode(mode)))
    pool_messages.MemberListHideDoneToggled ->
      opt.Some(#(handle_hide_closed_toggled(model), NoPersistence))
    pool_messages.MemberListCardToggled(card_id) ->
      opt.Some(#(handle_list_card_toggled(model, card_id), NoPersistence))
    _ -> opt.None
  }
}

pub fn handle_view_mode_set(
  model: member_pool.Model,
  mode: pool_prefs.ViewMode,
) -> member_pool.Model {
  member_pool.Model(..model, member_pool_view_mode: mode)
}

pub fn handle_hide_closed_toggled(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_list_hide_closed: !model.member_list_hide_closed,
  )
}

pub fn handle_list_card_toggled(
  model: member_pool.Model,
  card_id: Int,
) -> member_pool.Model {
  let current =
    dict.get(model.member_list_expanded_cards, card_id)
    |> opt.from_result
    |> list_card_expanded_or_default

  member_pool.Model(
    ..model,
    member_list_expanded_cards: dict.insert(
      model.member_list_expanded_cards,
      card_id,
      !current,
    ),
  )
}

fn list_card_expanded_or_default(expanded: opt.Option(Bool)) -> Bool {
  case expanded {
    opt.None -> True
    opt.Some(value) -> value
  }
}
