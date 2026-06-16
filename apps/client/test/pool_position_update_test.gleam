import gleam/dict
import gleam/option.{None, Some}

import lustre/effect

import domain/api_error.{type ApiError, type ApiResult, ApiError}
import domain/task.{type TaskPosition, TaskPosition}
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/position_update

fn context() -> position_update.Context(Nil) {
  position_update.Context(
    selected_project_id: None,
    invalid_xy: "Invalid XY",
    on_position_saved: fn(_result: ApiResult(TaskPosition)) { Nil },
    on_positions_fetched: fn(_result: ApiResult(List(TaskPosition))) { Nil },
    on_error_toast: fn(_message) { effect.none() },
  )
}

fn error() -> ApiError {
  ApiError(status: 500, code: "ERR", message: "boom")
}

fn position(task_id: Int, x: Int, y: Int) -> TaskPosition {
  TaskPosition(
    task_id: task_id,
    user_id: 3,
    x: x,
    y: y,
    updated_at: "2026-06-01T10:00:00Z",
  )
}

pub fn position_update_fetched_error_is_local_noop_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_positions_by_task: dict.from_list([#(7, #(12, 34))]),
    )

  let assert Some(position_update.Update(
    next,
    fx,
    position_update.CheckAuth(policy_err),
  )) =
    position_update.try_update(
      model,
      pool_messages.MemberPositionsFetched(Error(error())),
      context(),
    )

  let assert True = policy_err == error()
  let assert Ok(#(12, 34)) = dict.get(next.member_positions_by_task, 7)
  let assert True = fx == effect.none()
}

pub fn position_update_saved_ok_updates_dict_and_closes_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_task: Some(7),
      member_position_edit_in_flight: True,
    )

  let assert Some(position_update.Update(next, fx, position_update.NoAuthCheck)) =
    position_update.try_update(
      model,
      pool_messages.MemberPositionSaved(Ok(position(7, 44, 55))),
      context(),
    )

  let assert False = next.member_position_edit_in_flight
  let assert None = next.member_position_edit_task
  let assert Ok(#(44, 55)) = dict.get(next.member_positions_by_task, 7)
  let assert True = fx == effect.none()
}

pub fn position_update_saved_error_sets_error_and_refetches_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_in_flight: True,
    )

  let assert Some(position_update.Update(
    next,
    fx,
    position_update.CheckAuth(policy_err),
  )) =
    position_update.try_update(
      model,
      pool_messages.MemberPositionSaved(Error(error())),
      context(),
    )

  let assert True = policy_err == error()
  let assert False = next.member_position_edit_in_flight
  let assert Some("boom") = next.member_position_edit_error
  let assert False = fx == effect.none()
}

pub fn position_update_submitted_invalid_uses_context_message_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_task: Some(7),
      member_position_edit_x: "left",
      member_position_edit_y: "12",
    )

  let assert Some(position_update.Update(next, fx, position_update.NoAuthCheck)) =
    position_update.try_update(
      model,
      pool_messages.MemberPositionEditSubmitted,
      context(),
    )

  let assert Some("Invalid XY") = next.member_position_edit_error
  let assert False = next.member_position_edit_in_flight
  let assert True = fx == effect.none()
}

pub fn position_update_try_update_fetched_ok_without_auth_test() {
  let positions = [position(7, 44, 55)]

  let assert Some(position_update.Update(next, fx, position_update.NoAuthCheck)) =
    position_update.try_update(
      member_positions.default_model(),
      pool_messages.MemberPositionsFetched(Ok(positions)),
      context(),
    )

  let assert Ok(#(44, 55)) = dict.get(next.member_positions_by_task, 7)
  let assert True = fx == effect.none()
}

pub fn position_update_try_update_saved_error_checks_auth_test() {
  let err = error()
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_in_flight: True,
    )

  let assert Some(position_update.Update(
    next,
    fx,
    position_update.CheckAuth(policy_err),
  )) =
    position_update.try_update(
      model,
      pool_messages.MemberPositionSaved(Error(err)),
      context(),
    )

  let assert True = policy_err == err
  let assert False = next.member_position_edit_in_flight
  let assert Some("boom") = next.member_position_edit_error
  let assert False = fx == effect.none()
}

pub fn position_update_try_update_ignores_non_position_messages_test() {
  let assert None =
    position_update.try_update(
      member_positions.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      context(),
    )
}
