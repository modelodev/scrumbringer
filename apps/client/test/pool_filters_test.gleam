import gleam/option.{None, Some}

import domain/task_status.{Available, Completed}
import scrumbringer_client/capability_scope.{AllCapabilities, MyCapabilities}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/filters
import scrumbringer_client/features/pool/msg as pool_messages

fn default_pool() -> member_pool.Model {
  member_pool.default_model()
}

pub fn status_changed_parses_status_and_requests_refresh_test() {
  let #(pool, should_refresh) =
    filters.handle_status_changed(default_pool(), "available")

  let assert Some(Available) = pool.member_filters_status
  let assert True = should_refresh
}

pub fn status_changed_clears_blank_or_invalid_and_requests_refresh_test() {
  let pool =
    member_pool.Model(..default_pool(), member_filters_status: Some(Completed))

  let #(blank_pool, blank_refresh) = filters.handle_status_changed(pool, "  ")
  let #(invalid_pool, invalid_refresh) =
    filters.handle_status_changed(pool, "unknown")

  let assert None = blank_pool.member_filters_status
  let assert True = blank_refresh
  let assert None = invalid_pool.member_filters_status
  let assert True = invalid_refresh
}

pub fn type_changed_parses_int_and_requests_refresh_test() {
  let #(pool, should_refresh) =
    filters.handle_type_changed(default_pool(), "42")

  let assert Some(42) = pool.member_filters_type_id
  let assert True = should_refresh
}

pub fn capability_changed_parses_int_and_requests_refresh_test() {
  let #(pool, should_refresh) =
    filters.handle_capability_changed(default_pool(), "7")

  let assert Some(7) = pool.member_filters_capability_id
  let assert True = should_refresh
}

pub fn search_changed_updates_without_refresh_test() {
  let #(pool, should_refresh) =
    filters.handle_search_changed(default_pool(), "backend")

  let assert "backend" = pool.member_filters_q
  let assert False = should_refresh
}

pub fn search_debounced_updates_and_requests_refresh_test() {
  let #(pool, should_refresh) =
    filters.handle_search_debounced(default_pool(), "backend")

  let assert "backend" = pool.member_filters_q
  let assert True = should_refresh
}

pub fn clear_resets_all_filters_and_scope_test() {
  let pool =
    member_pool.Model(
      ..default_pool(),
      member_filters_status: Some(Completed),
      member_filters_type_id: Some(11),
      member_filters_capability_id: Some(12),
      member_filters_q: "backend",
      member_capability_scope: MyCapabilities,
    )

  let #(next, should_refresh) = filters.handle_clear(pool)

  let assert None = next.member_filters_status
  let assert None = next.member_filters_type_id
  let assert None = next.member_filters_capability_id
  let assert "" = next.member_filters_q
  let assert AllCapabilities = next.member_capability_scope
  let assert True = should_refresh
}

pub fn capability_scope_changed_accepts_valid_and_rejects_invalid_test() {
  let pool = default_pool()

  let #(mine_pool, mine_refresh) =
    filters.handle_capability_scope_changed(pool, "mine")
  let #(invalid_pool, invalid_refresh) =
    filters.handle_capability_scope_changed(mine_pool, "unknown")

  let assert MyCapabilities = mine_pool.member_capability_scope
  let assert True = mine_refresh
  let assert MyCapabilities = invalid_pool.member_capability_scope
  let assert False = invalid_refresh
}

pub fn filters_try_update_handles_refreshing_filter_message_test() {
  let assert Some(#(pool, should_refresh)) =
    filters.try_update(
      default_pool(),
      pool_messages.MemberPoolStatusChanged("available"),
    )

  let assert Some(Available) = pool.member_filters_status
  let assert True = should_refresh
}

pub fn filters_try_update_handles_non_refreshing_search_message_test() {
  let assert Some(#(pool, should_refresh)) =
    filters.try_update(
      default_pool(),
      pool_messages.MemberPoolSearchChanged("backend"),
    )

  let assert "backend" = pool.member_filters_q
  let assert False = should_refresh
}

pub fn filters_try_update_ignores_non_filter_message_test() {
  let assert None =
    filters.try_update(default_pool(), pool_messages.MemberPoolFiltersToggled)
}
