//// Member task position edit workflow.

import gleam/dict
import gleam/int
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/task.{type TaskPosition, TaskPosition}
import scrumbringer_client/api/tasks/positions as task_positions_api
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/helpers/dicts as helpers_dicts

pub type Context(parent_msg) {
  Context(
    invalid_xy: String,
    on_position_saved: fn(ApiResult(TaskPosition)) -> parent_msg,
  )
}

pub fn handle_opened(
  model: member_positions.Model,
  task_id: Int,
) -> #(member_positions.Model, Effect(parent_msg)) {
  let #(x, y) = case dict.get(model.member_positions_by_task, task_id) {
    Ok(xy) -> xy
    Error(_) -> #(0, 0)
  }

  #(
    member_positions.Model(
      ..model,
      member_position_edit_task: opt.Some(task_id),
      member_position_edit_x: int.to_string(x),
      member_position_edit_y: int.to_string(y),
      member_position_edit_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_closed(
  model: member_positions.Model,
) -> #(member_positions.Model, Effect(parent_msg)) {
  #(
    member_positions.Model(
      ..model,
      member_position_edit_task: opt.None,
      member_position_edit_error: opt.None,
    ),
    effect.none(),
  )
}

pub fn handle_x_changed(
  model: member_positions.Model,
  value: String,
) -> #(member_positions.Model, Effect(parent_msg)) {
  #(
    member_positions.Model(..model, member_position_edit_x: value),
    effect.none(),
  )
}

pub fn handle_y_changed(
  model: member_positions.Model,
  value: String,
) -> #(member_positions.Model, Effect(parent_msg)) {
  #(
    member_positions.Model(..model, member_position_edit_y: value),
    effect.none(),
  )
}

pub fn handle_submitted(
  model: member_positions.Model,
  context: Context(parent_msg),
) -> #(member_positions.Model, Effect(parent_msg)) {
  case model.member_position_edit_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.member_position_edit_task {
        opt.None -> #(model, effect.none())
        opt.Some(task_id) -> submit(model, task_id, context)
      }
  }
}

fn submit(
  model: member_positions.Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(member_positions.Model, Effect(parent_msg)) {
  case
    int.parse(model.member_position_edit_x),
    int.parse(model.member_position_edit_y)
  {
    Ok(x), Ok(y) -> submit_valid(model, task_id, x, y, context)
    _, _ -> submit_invalid(model, context.invalid_xy)
  }
}

fn submit_valid(
  model: member_positions.Model,
  task_id: Int,
  x: Int,
  y: Int,
  context: Context(parent_msg),
) -> #(member_positions.Model, Effect(parent_msg)) {
  #(
    member_positions.Model(
      ..model,
      member_position_edit_in_flight: True,
      member_position_edit_error: opt.None,
    ),
    task_positions_api.upsert_me_task_position(
      task_id,
      x,
      y,
      context.on_position_saved,
    ),
  )
}

fn submit_invalid(
  model: member_positions.Model,
  message: String,
) -> #(member_positions.Model, Effect(parent_msg)) {
  #(
    member_positions.Model(
      ..model,
      member_position_edit_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn handle_saved_ok(
  model: member_positions.Model,
  pos: TaskPosition,
) -> #(member_positions.Model, Effect(parent_msg)) {
  let TaskPosition(task_id: task_id, x: x, y: y, ..) = pos

  #(
    member_positions.Model(
      ..model,
      member_position_edit_in_flight: False,
      member_position_edit_task: opt.None,
      member_positions_by_task: dict.insert(
        model.member_positions_by_task,
        task_id,
        #(x, y),
      ),
    ),
    effect.none(),
  )
}

pub fn handle_saved_error(
  model: member_positions.Model,
  message: String,
) -> #(member_positions.Model, Effect(parent_msg)) {
  #(
    member_positions.Model(
      ..model,
      member_position_edit_in_flight: False,
      member_position_edit_error: opt.Some(message),
    ),
    effect.none(),
  )
}

pub fn handle_fetched_ok(
  model: member_positions.Model,
  positions: List(TaskPosition),
) -> #(member_positions.Model, Effect(parent_msg)) {
  #(
    member_positions.Model(
      ..model,
      member_positions_by_task: helpers_dicts.positions_to_dict(positions),
    ),
    effect.none(),
  )
}
