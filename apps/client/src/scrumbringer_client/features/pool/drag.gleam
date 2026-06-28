//// Member pool drag state transitions.

import gleam/option

import scrumbringer_client/client_state/member/pool as member_pool

pub fn drag_to_claim_armed(
  model: member_pool.Model,
  armed: Bool,
) -> member_pool.Model {
  let next_drag = case armed, model.member_pool_drag {
    True, member_pool.PoolDragDragging(rect: rect, ..) ->
      member_pool.PoolDragDragging(over_my_tasks: False, rect: rect)
    True, member_pool.PoolDragPendingRect -> member_pool.PoolDragPendingRect
    True, member_pool.PoolDragIdle -> member_pool.PoolDragPendingRect
    False, _ -> member_pool.PoolDragIdle
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
  let rect =
    member_pool.Rect(left: left, top: top, width: width, height: height)
  let next_drag = case model.member_pool_drag, model.member_drag {
    member_pool.PoolDragDragging(over_my_tasks: over, ..), _ ->
      member_pool.PoolDragDragging(over_my_tasks: over, rect: rect)
    member_pool.PoolDragPendingRect, member_pool.DragIdle ->
      member_pool.PoolDragIdle
    member_pool.PoolDragPendingRect, _ ->
      member_pool.PoolDragDragging(over_my_tasks: False, rect: rect)
    member_pool.PoolDragIdle, _ -> member_pool.PoolDragIdle
  }

  member_pool.Model(..model, member_pool_drag: next_drag)
}

pub fn start(model: member_pool.Model, task_id: Int) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_drag: member_pool.DragPending(task_id),
    member_pool_drag: member_pool.PoolDragPendingRect,
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
    member_pool.DragPending(drag_task_id) ->
      case drag_task_id == task_id {
        True -> member_pool.DragActive(task_id, offset_x, offset_y)
        False -> model.member_drag
      }
    member_pool.DragActive(_, _, _) -> model.member_drag
    member_pool.DragIdle -> member_pool.DragIdle
  }

  member_pool.Model(..model, member_drag: updated)
}

pub fn is_pending(model: member_pool.Model) -> Bool {
  case model.member_drag {
    member_pool.DragPending(_) -> True
    _ -> False
  }
}

pub fn active(model: member_pool.Model) -> option.Option(#(Int, Int, Int)) {
  case model.member_drag {
    member_pool.DragActive(task_id, offset_x, offset_y) ->
      option.Some(#(task_id, offset_x, offset_y))
    _ -> option.None
  }
}

pub fn task_id(model: member_pool.Model) -> option.Option(Int) {
  case model.member_drag {
    member_pool.DragIdle -> option.None
    member_pool.DragPending(task_id) | member_pool.DragActive(task_id, _, _) ->
      option.Some(task_id)
  }
}

pub fn is_over_my_tasks(model: member_pool.Model) -> Bool {
  case model.member_pool_drag {
    member_pool.PoolDragDragging(over_my_tasks: over, ..) -> over
    _ -> False
  }
}

pub fn clear(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_drag: member_pool.DragIdle,
    member_pool_drag: member_pool.PoolDragIdle,
  )
}

fn pool_drag_over_my_tasks(
  drag_state: member_pool.PoolDragState,
  client_x: Int,
  client_y: Int,
) -> Bool {
  case drag_state {
    member_pool.PoolDragDragging(rect: rect, ..) ->
      member_pool.rect_contains_point(rect, client_x, client_y)
    _ -> False
  }
}

fn next_pool_drag_state(
  drag_state: member_pool.PoolDragState,
  over_my_tasks: Bool,
) -> member_pool.PoolDragState {
  case drag_state {
    member_pool.PoolDragDragging(rect: rect, ..) ->
      member_pool.PoolDragDragging(over_my_tasks: over_my_tasks, rect: rect)
    member_pool.PoolDragPendingRect -> member_pool.PoolDragPendingRect
    member_pool.PoolDragIdle -> member_pool.PoolDragIdle
  }
}
