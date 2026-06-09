//// Member pool drag state transitions.

import gleam/option

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/types.{
  type PoolDragState, DragActive, DragIdle, DragPending, PoolDragDragging,
  PoolDragIdle, PoolDragPendingRect, Rect, rect_contains_point,
}

pub fn drag_to_claim_armed(
  model: member_pool.Model,
  armed: Bool,
) -> member_pool.Model {
  let next_drag = case armed, model.member_pool_drag {
    True, PoolDragDragging(rect: rect, ..) ->
      PoolDragDragging(over_my_tasks: False, rect: rect)
    True, PoolDragPendingRect -> PoolDragPendingRect
    True, PoolDragIdle -> PoolDragPendingRect
    False, _ -> PoolDragIdle
  }

  member_pool.Model(..model, member_pool_drag: next_drag)
}

pub fn my_tasks_rect_fetched(
  model: member_pool.Model,
  left: Int,
  top: Int,
  width: Int,
  height: Int,
) -> member_pool.Model {
  let rect = Rect(left: left, top: top, width: width, height: height)
  let next_drag = case model.member_pool_drag, model.member_drag {
    PoolDragDragging(over_my_tasks: over, ..), _ ->
      PoolDragDragging(over_my_tasks: over, rect: rect)
    PoolDragPendingRect, DragIdle -> PoolDragIdle
    PoolDragPendingRect, _ -> PoolDragDragging(over_my_tasks: False, rect: rect)
    PoolDragIdle, _ -> PoolDragIdle
  }

  member_pool.Model(..model, member_pool_drag: next_drag)
}

pub fn start(model: member_pool.Model, task_id: Int) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_drag: DragPending(task_id),
    member_pool_drag: PoolDragPendingRect,
  )
}

pub fn move(
  model: member_pool.Model,
  client_x: Int,
  client_y: Int,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_pool_drag: next_pool_drag_state(
      model.member_pool_drag,
      pool_drag_over_my_tasks(model.member_pool_drag, client_x, client_y),
    ),
  )
}

pub fn offset_resolved(
  model: member_pool.Model,
  task_id: Int,
  offset_x: Int,
  offset_y: Int,
) -> member_pool.Model {
  let updated = case model.member_drag {
    DragPending(drag_task_id) ->
      case drag_task_id == task_id {
        True -> DragActive(task_id, offset_x, offset_y)
        False -> model.member_drag
      }
    DragActive(_, _, _) -> model.member_drag
    DragIdle -> DragIdle
  }

  member_pool.Model(..model, member_drag: updated)
}

pub fn is_idle(model: member_pool.Model) -> Bool {
  case model.member_drag {
    DragIdle -> True
    _ -> False
  }
}

pub fn is_pending(model: member_pool.Model) -> Bool {
  case model.member_drag {
    DragPending(_) -> True
    _ -> False
  }
}

pub fn active(model: member_pool.Model) -> option.Option(#(Int, Int, Int)) {
  case model.member_drag {
    DragActive(task_id, offset_x, offset_y) ->
      option.Some(#(task_id, offset_x, offset_y))
    _ -> option.None
  }
}

pub fn task_id(model: member_pool.Model) -> option.Option(Int) {
  case model.member_drag {
    DragIdle -> option.None
    DragPending(task_id) | DragActive(task_id, _, _) -> option.Some(task_id)
  }
}

pub fn is_over_my_tasks(model: member_pool.Model) -> Bool {
  case model.member_pool_drag {
    PoolDragDragging(over_my_tasks: over, ..) -> over
    _ -> False
  }
}

pub fn clear(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_drag: DragIdle,
    member_pool_drag: PoolDragIdle,
  )
}

fn pool_drag_over_my_tasks(
  drag_state: PoolDragState,
  client_x: Int,
  client_y: Int,
) -> Bool {
  case drag_state {
    PoolDragDragging(rect: rect, ..) ->
      rect_contains_point(rect, client_x, client_y)
    _ -> False
  }
}

fn next_pool_drag_state(
  drag_state: PoolDragState,
  over_my_tasks: Bool,
) -> PoolDragState {
  case drag_state {
    PoolDragDragging(rect: rect, ..) ->
      PoolDragDragging(over_my_tasks: over_my_tasks, rect: rect)
    PoolDragPendingRect -> PoolDragPendingRect
    PoolDragIdle -> PoolDragIdle
  }
}
