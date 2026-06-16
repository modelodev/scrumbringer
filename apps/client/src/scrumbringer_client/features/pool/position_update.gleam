//// Effectful position edit workflow for the member pool.

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/task.{type TaskPosition}
import scrumbringer_client/api/tasks/positions as task_positions_api
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/position_edit

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(member_positions.Model, Effect(parent_msg), AuthPolicy)
}

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    invalid_xy: String,
    on_position_saved: fn(ApiResult(TaskPosition)) -> parent_msg,
    on_positions_fetched: fn(ApiResult(List(TaskPosition))) -> parent_msg,
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub fn try_update(
  model: member_positions.Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberPositionsFetched(Ok(positions)) ->
      fetched_ok(model, positions)
      |> without_auth_check

    pool_messages.MemberPositionsFetched(Error(err)) ->
      fetched_error(model, err)
      |> with_auth_check(err)

    pool_messages.MemberPositionEditOpened(task_id) ->
      opened(model, task_id)
      |> without_auth_check

    pool_messages.MemberPositionEditClosed ->
      closed(model)
      |> without_auth_check

    pool_messages.MemberPositionEditXChanged(value) ->
      x_changed(model, value)
      |> without_auth_check

    pool_messages.MemberPositionEditYChanged(value) ->
      y_changed(model, value)
      |> without_auth_check

    pool_messages.MemberPositionEditSubmitted ->
      submitted(model, context)
      |> without_auth_check

    pool_messages.MemberPositionSaved(Ok(position)) ->
      saved_ok(model, position)
      |> without_auth_check

    pool_messages.MemberPositionSaved(Error(err)) ->
      saved_error(model, err, context)
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(member_positions.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, NoAuthCheck))
}

fn with_auth_check(
  result: #(member_positions.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, CheckAuth(err)))
}

fn fetched_ok(
  model: member_positions.Model,
  positions: List(TaskPosition),
) -> #(member_positions.Model, Effect(parent_msg)) {
  position_edit.handle_fetched_ok(model, positions)
}

fn fetched_error(
  model: member_positions.Model,
  _err: ApiError,
) -> #(member_positions.Model, Effect(parent_msg)) {
  #(model, effect.none())
}

fn opened(
  model: member_positions.Model,
  task_id: Int,
) -> #(member_positions.Model, Effect(parent_msg)) {
  position_edit.handle_opened(model, task_id)
}

fn closed(
  model: member_positions.Model,
) -> #(member_positions.Model, Effect(parent_msg)) {
  position_edit.handle_closed(model)
}

fn x_changed(
  model: member_positions.Model,
  value: String,
) -> #(member_positions.Model, Effect(parent_msg)) {
  position_edit.handle_x_changed(model, value)
}

fn y_changed(
  model: member_positions.Model,
  value: String,
) -> #(member_positions.Model, Effect(parent_msg)) {
  position_edit.handle_y_changed(model, value)
}

fn submitted(
  model: member_positions.Model,
  context: Context(parent_msg),
) -> #(member_positions.Model, Effect(parent_msg)) {
  position_edit.handle_submitted(model, edit_context(context))
}

fn saved_ok(
  model: member_positions.Model,
  position: TaskPosition,
) -> #(member_positions.Model, Effect(parent_msg)) {
  position_edit.handle_saved_ok(model, position)
}

fn saved_error(
  model: member_positions.Model,
  err: ApiError,
  context: Context(parent_msg),
) -> #(member_positions.Model, Effect(parent_msg)) {
  let #(next, local_fx) = position_edit.handle_saved_error(model, err.message)
  #(
    next,
    effect.batch([
      local_fx,
      refetch_positions_effect(context),
      context.on_error_toast(err.message),
    ]),
  )
}

fn edit_context(
  context: Context(parent_msg),
) -> position_edit.Context(parent_msg) {
  position_edit.Context(
    invalid_xy: context.invalid_xy,
    on_position_saved: context.on_position_saved,
  )
}

fn refetch_positions_effect(context: Context(parent_msg)) -> Effect(parent_msg) {
  task_positions_api.list_me_task_positions(
    context.selected_project_id,
    context.on_positions_fetched,
  )
}
