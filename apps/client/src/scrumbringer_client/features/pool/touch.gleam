//// Member pool touch and long-press state transitions.

import gleam/option

import scrumbringer_client/client_state/member/pool as member_pool

pub fn start(
  model: member_pool.Model,
  task_id: Int,
  client_x: Int,
  client_y: Int,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_pool_touch_task_id: option.Some(task_id),
    member_pool_touch_longpress: option.None,
    member_pool_touch_client_x: client_x,
    member_pool_touch_client_y: client_y,
  )
}

pub fn clear(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_pool_touch_task_id: option.None,
    member_pool_touch_longpress: option.None,
    member_pool_touch_client_x: 0,
    member_pool_touch_client_y: 0,
  )
}

pub fn end_preview(model: member_pool.Model, task_id: Int) -> member_pool.Model {
  let next_preview = case model.member_pool_preview_task_id {
    option.Some(id) if id == task_id -> option.None
    _ -> option.Some(task_id)
  }

  member_pool.Model(..clear(model), member_pool_preview_task_id: next_preview)
}

pub fn mark_longpress(
  model: member_pool.Model,
  task_id: Int,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_pool_touch_longpress: option.Some(task_id),
    member_pool_preview_task_id: option.None,
  )
}

pub fn is_longpress_for(model: member_pool.Model, task_id: Int) -> Bool {
  case model.member_pool_touch_longpress {
    option.Some(id) if id == task_id -> True
    _ -> False
  }
}

pub fn is_pending_for(model: member_pool.Model, task_id: Int) -> Bool {
  case model.member_pool_touch_task_id {
    option.Some(id) if id == task_id -> True
    _ -> False
  }
}

pub fn client_x(model: member_pool.Model) -> Int {
  model.member_pool_touch_client_x
}

pub fn client_y(model: member_pool.Model) -> Int {
  model.member_pool_touch_client_y
}
