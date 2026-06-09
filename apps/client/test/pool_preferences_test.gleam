import gleam/dict
import gleam/option.{type Option, None, Some}

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/preferences
import scrumbringer_client/pool_prefs

fn default_pool() -> member_pool.Model {
  member_pool.default_model()
}

pub fn filters_toggled_flips_visibility_and_returns_value_to_persist_test() {
  let #(visible_pool, visible) =
    preferences.handle_filters_toggled(default_pool())
  let #(hidden_pool, hidden) = preferences.handle_filters_toggled(visible_pool)

  let assert True = visible_pool.member_pool_filters_visible
  let assert True = visible
  let assert False = hidden_pool.member_pool_filters_visible
  let assert False = hidden
}

pub fn try_update_handles_filters_toggled_with_persistence_test() {
  let assert Some(#(pool, preferences.SaveFiltersVisible(True))) =
    preferences.try_update(
      default_pool(),
      pool_messages.MemberPoolFiltersToggled,
    )

  let assert True = pool.member_pool_filters_visible
}

pub fn filters_shown_only_requests_persistence_when_visibility_changes_test() {
  let #(shown_pool, should_save) =
    preferences.handle_filters_shown(default_pool())
  let #(same_pool, should_not_save) =
    preferences.handle_filters_shown(shown_pool)

  let assert True = shown_pool.member_pool_filters_visible
  let assert True = should_save
  let assert True = same_pool.member_pool_filters_visible
  let assert False = should_not_save
}

pub fn view_mode_set_updates_pool_preference_test() {
  let pool = preferences.handle_view_mode_set(default_pool(), pool_prefs.List)

  let assert pool_prefs.List = pool.member_pool_view_mode
}

pub fn try_update_handles_view_mode_set_with_persistence_test() {
  let assert Some(#(pool, preferences.SaveViewMode(pool_prefs.List))) =
    preferences.try_update(
      default_pool(),
      pool_messages.MemberPoolViewModeSet(pool_prefs.List),
    )

  let assert pool_prefs.List = pool.member_pool_view_mode
}

pub fn hide_completed_toggled_flips_list_preference_test() {
  let visible_completed =
    member_pool.Model(..default_pool(), member_list_hide_completed: False)
  let hidden_completed =
    preferences.handle_hide_completed_toggled(visible_completed)

  let assert False = visible_completed.member_list_hide_completed
  let assert True = hidden_completed.member_list_hide_completed
}

pub fn try_update_handles_hide_completed_without_persistence_test() {
  let visible_completed =
    member_pool.Model(..default_pool(), member_list_hide_completed: False)

  let assert Some(#(pool, preferences.NoPersistence)) =
    preferences.try_update(
      visible_completed,
      pool_messages.MemberListHideCompletedToggled,
    )

  let assert True = pool.member_list_hide_completed
}

pub fn list_card_toggled_collapses_missing_card_by_default_test() {
  let pool = preferences.handle_list_card_toggled(default_pool(), 7)

  let assert Ok(False) = dict.get(pool.member_list_expanded_cards, 7)
}

pub fn try_update_handles_list_card_toggle_without_persistence_test() {
  let assert Some(#(pool, preferences.NoPersistence)) =
    preferences.try_update(
      default_pool(),
      pool_messages.MemberListCardToggled(7),
    )

  let assert Ok(False) = dict.get(pool.member_list_expanded_cards, 7)
}

pub fn try_update_ignores_non_preference_messages_test() {
  let assert None =
    preferences.try_update(
      default_pool(),
      pool_messages.MemberPoolStatusChanged("available"),
    )
}

pub fn list_card_toggled_flips_existing_card_value_test() {
  let pool =
    member_pool.Model(
      ..default_pool(),
      member_list_expanded_cards: dict.from_list([#(7, False)]),
    )

  let next = preferences.handle_list_card_toggled(pool, 7)

  let assert Ok(True) = dict.get(next.member_list_expanded_cards, 7)
}

pub fn list_card_toggled_preserves_other_card_values_test() {
  let pool =
    member_pool.Model(
      ..default_pool(),
      member_list_expanded_cards: dict.from_list([#(7, False), #(8, True)]),
    )

  let next = preferences.handle_list_card_toggled(pool, 7)

  let assert Ok(True) = dict.get(next.member_list_expanded_cards, 7)
  let assert Ok(True) = dict.get(next.member_list_expanded_cards, 8)
  let assert None =
    dict.get(next.member_list_expanded_cards, 99)
    |> option_from_result
}

fn option_from_result(result: Result(a, b)) -> Option(a) {
  case result {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}
