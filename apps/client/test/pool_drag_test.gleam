import gleam/option.{None, Some}

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/pool/drag

fn default_pool() -> member_pool.Model {
  member_pool.default_model()
}

fn rect() -> state_types.Rect {
  state_types.Rect(left: 10, top: 20, width: 100, height: 50)
}

pub fn drag_to_claim_armed_moves_idle_to_pending_rect_test() {
  let next = drag.drag_to_claim_armed(default_pool(), True)

  let assert state_types.PoolDragPendingRect = next.member_pool_drag
}

pub fn drag_to_claim_armed_preserves_rect_and_resets_over_state_test() {
  let pool =
    member_pool.Model(
      ..default_pool(),
      member_pool_drag: state_types.PoolDragDragging(
        over_my_tasks: True,
        rect: rect(),
      ),
    )

  let next = drag.drag_to_claim_armed(pool, True)

  let assert state_types.PoolDragDragging(
    over_my_tasks: False,
    rect: state_types.Rect(left: 10, top: 20, width: 100, height: 50),
  ) = next.member_pool_drag
}

pub fn drag_to_claim_disarmed_clears_pool_drag_test() {
  let pool = drag.drag_to_claim_armed(default_pool(), True)

  let next = drag.drag_to_claim_armed(pool, False)

  let assert state_types.PoolDragIdle = next.member_pool_drag
}

pub fn my_tasks_rect_fetched_without_card_drag_clears_pending_rect_test() {
  let pool = drag.drag_to_claim_armed(default_pool(), True)

  let next = drag.my_tasks_rect_fetched(pool, 10, 20, 100, 50)

  let assert state_types.PoolDragIdle = next.member_pool_drag
}

pub fn my_tasks_rect_fetched_with_pending_drag_enters_dragging_test() {
  let pool = drag.start(default_pool(), 7)

  let next = drag.my_tasks_rect_fetched(pool, 10, 20, 100, 50)

  let assert state_types.PoolDragDragging(
    over_my_tasks: False,
    rect: state_types.Rect(left: 10, top: 20, width: 100, height: 50),
  ) = next.member_pool_drag
}

pub fn start_marks_task_pending_and_requests_drop_rect_test() {
  let next = drag.start(default_pool(), 7)

  let assert state_types.DragPending(7) = next.member_drag
  let assert state_types.PoolDragPendingRect = next.member_pool_drag
}

pub fn move_updates_over_my_tasks_from_rect_hit_test() {
  let pool =
    member_pool.Model(
      ..default_pool(),
      member_pool_drag: state_types.PoolDragDragging(
        over_my_tasks: False,
        rect: rect(),
      ),
    )

  let next = drag.move(pool, 15, 25)

  let assert state_types.PoolDragDragging(
    over_my_tasks: True,
    rect: state_types.Rect(left: 10, top: 20, width: 100, height: 50),
  ) = next.member_pool_drag
}

pub fn offset_resolved_activates_matching_pending_drag_test() {
  let pool = drag.start(default_pool(), 7)

  let next = drag.offset_resolved(pool, 7, 3, 4)

  let assert state_types.DragActive(7, 3, 4) = next.member_drag
  let assert Some(#(7, 3, 4)) = drag.active(next)
}

pub fn offset_resolved_ignores_different_pending_task_test() {
  let pool = drag.start(default_pool(), 7)

  let next = drag.offset_resolved(pool, 8, 3, 4)

  let assert state_types.DragPending(7) = next.member_drag
}

pub fn task_id_returns_pending_or_active_task_test() {
  let pending = drag.start(default_pool(), 7)
  let active = drag.offset_resolved(pending, 7, 3, 4)

  let assert Some(7) = drag.task_id(pending)
  let assert Some(7) = drag.task_id(active)
  let assert None = drag.task_id(default_pool())
}

pub fn clear_resets_drag_state_test() {
  let pool =
    default_pool()
    |> drag.start(7)
    |> drag.offset_resolved(7, 3, 4)

  let next = drag.clear(pool)

  let assert state_types.DragIdle = next.member_drag
  let assert state_types.PoolDragIdle = next.member_pool_drag
}
