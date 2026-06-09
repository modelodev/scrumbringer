import gleam/option.{None, Some}

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/touch

fn default_pool() -> member_pool.Model {
  member_pool.default_model()
}

pub fn start_records_task_coordinates_and_clears_longpress_test() {
  let pool =
    member_pool.Model(..default_pool(), member_pool_touch_longpress: Some(99))

  let next = touch.start(pool, 7, 12, 34)

  let assert Some(7) = next.member_pool_touch_task_id
  let assert None = next.member_pool_touch_longpress
  let assert 12 = next.member_pool_touch_client_x
  let assert 34 = next.member_pool_touch_client_y
}

pub fn clear_resets_touch_tracking_test() {
  let pool =
    default_pool()
    |> touch.start(7, 12, 34)
    |> touch.mark_longpress(7)

  let next = touch.clear(pool)

  let assert None = next.member_pool_touch_task_id
  let assert None = next.member_pool_touch_longpress
  let assert 0 = next.member_pool_touch_client_x
  let assert 0 = next.member_pool_touch_client_y
}

pub fn end_preview_opens_preview_and_clears_touch_test() {
  let pool = touch.start(default_pool(), 7, 12, 34)

  let next = touch.end_preview(pool, 7)

  let assert Some(7) = next.member_pool_preview_task_id
  let assert None = next.member_pool_touch_task_id
  let assert None = next.member_pool_touch_longpress
  let assert 0 = next.member_pool_touch_client_x
  let assert 0 = next.member_pool_touch_client_y
}

pub fn end_preview_closes_preview_for_same_task_test() {
  let pool =
    member_pool.Model(
      ..touch.start(default_pool(), 7, 12, 34),
      member_pool_preview_task_id: Some(7),
    )

  let next = touch.end_preview(pool, 7)

  let assert None = next.member_pool_preview_task_id
  let assert None = next.member_pool_touch_task_id
}

pub fn end_preview_switches_preview_for_different_task_test() {
  let pool =
    member_pool.Model(
      ..touch.start(default_pool(), 8, 12, 34),
      member_pool_preview_task_id: Some(7),
    )

  let next = touch.end_preview(pool, 8)

  let assert Some(8) = next.member_pool_preview_task_id
  let assert None = next.member_pool_touch_task_id
}

pub fn mark_longpress_records_task_and_closes_preview_test() {
  let pool =
    member_pool.Model(
      ..touch.start(default_pool(), 7, 12, 34),
      member_pool_preview_task_id: Some(7),
    )

  let next = touch.mark_longpress(pool, 7)

  let assert Some(7) = next.member_pool_touch_longpress
  let assert None = next.member_pool_preview_task_id
}

pub fn longpress_predicate_matches_only_current_task_test() {
  let pool =
    default_pool()
    |> touch.start(7, 12, 34)
    |> touch.mark_longpress(7)

  let assert True = touch.is_longpress_for(pool, 7)
  let assert False = touch.is_longpress_for(pool, 8)
}

pub fn pending_predicate_matches_only_current_task_test() {
  let pool = touch.start(default_pool(), 7, 12, 34)

  let assert True = touch.is_pending_for(pool, 7)
  let assert False = touch.is_pending_for(pool, 8)
}

pub fn coordinate_accessors_return_recorded_touch_position_test() {
  let pool = touch.start(default_pool(), 7, 12, 34)

  let assert 12 = touch.client_x(pool)
  let assert 34 = touch.client_y(pool)
}
