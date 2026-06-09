//// JSON presenters for task position endpoints.

import gleam/json
import scrumbringer_server/services/task_positions_db

pub fn positions(positions: List(task_positions_db.TaskPosition)) -> json.Json {
  json.array(positions, of: position)
}

pub fn positions_response(
  values: List(task_positions_db.TaskPosition),
) -> json.Json {
  json.object([#("positions", positions(values))])
}

pub fn position(position: task_positions_db.TaskPosition) -> json.Json {
  let task_positions_db.TaskPosition(
    task_id: task_id,
    user_id: user_id,
    x: x,
    y: y,
    updated_at: updated_at,
  ) = position

  json.object([
    #("task_id", json.int(task_id)),
    #("user_id", json.int(user_id)),
    #("x", json.int(x)),
    #("y", json.int(y)),
    #("updated_at", json.string(updated_at)),
  ])
}

pub fn position_response(value: task_positions_db.TaskPosition) -> json.Json {
  json.object([#("position", position(value))])
}
