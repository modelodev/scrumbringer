import gleam/dict
import gleam/option.{None, Some}
import lustre/effect

import domain/task.{TaskPosition}
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/position_edit

fn context() -> position_edit.Context(Nil) {
  position_edit.Context(
    invalid_xy: "Invalid XY",
    on_position_saved: fn(_result) { Nil },
  )
}

pub fn opened_uses_existing_position_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_positions_by_task: dict.from_list([#(7, #(12, 34))]),
    )

  let #(next, fx) = position_edit.handle_opened(model, 7)

  let assert Some(7) = next.member_position_edit_task
  let assert "12" = next.member_position_edit_x
  let assert "34" = next.member_position_edit_y
  let assert None = next.member_position_edit_error
  let assert True = fx == effect.none()
}

pub fn opened_defaults_missing_position_to_origin_test() {
  let #(next, fx) =
    position_edit.handle_opened(member_positions.default_model(), 9)

  let assert Some(9) = next.member_position_edit_task
  let assert "0" = next.member_position_edit_x
  let assert "0" = next.member_position_edit_y
  let assert True = fx == effect.none()
}

pub fn closed_clears_task_and_error_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_task: Some(7),
      member_position_edit_error: Some("boom"),
    )

  let #(next, fx) = position_edit.handle_closed(model)

  let assert None = next.member_position_edit_task
  let assert None = next.member_position_edit_error
  let assert True = fx == effect.none()
}

pub fn changed_updates_x_and_y_test() {
  let #(with_x, x_fx) =
    position_edit.handle_x_changed(member_positions.default_model(), "17")
  let #(with_y, y_fx) = position_edit.handle_y_changed(with_x, "23")

  let assert "17" = with_y.member_position_edit_x
  let assert "23" = with_y.member_position_edit_y
  let assert True = x_fx == effect.none()
  let assert True = y_fx == effect.none()
}

pub fn submitted_invalid_sets_error_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_task: Some(7),
      member_position_edit_x: "left",
      member_position_edit_y: "12",
    )

  let #(next, fx) = position_edit.handle_submitted(model, context())

  let assert Some("Invalid XY") = next.member_position_edit_error
  let assert False = next.member_position_edit_in_flight
  let assert True = fx == effect.none()
}

pub fn submitted_noops_when_no_task_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_task: None,
      member_position_edit_x: "1",
      member_position_edit_y: "2",
    )

  let #(next, fx) = position_edit.handle_submitted(model, context())

  let assert None = next.member_position_edit_task
  let assert False = next.member_position_edit_in_flight
  let assert True = fx == effect.none()
}

pub fn submitted_noops_when_in_flight_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_task: Some(7),
      member_position_edit_x: "1",
      member_position_edit_y: "2",
      member_position_edit_in_flight: True,
      member_position_edit_error: Some("old"),
    )

  let #(next, fx) = position_edit.handle_submitted(model, context())

  let assert True = next.member_position_edit_in_flight
  let assert Some("old") = next.member_position_edit_error
  let assert True = fx == effect.none()
}

pub fn submitted_valid_sets_in_flight_and_clears_error_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_task: Some(7),
      member_position_edit_x: "1",
      member_position_edit_y: "2",
      member_position_edit_error: Some("old"),
    )

  let #(next, fx) = position_edit.handle_submitted(model, context())

  let assert True = next.member_position_edit_in_flight
  let assert None = next.member_position_edit_error
  let assert False = fx == effect.none()
}

pub fn saved_ok_closes_dialog_and_updates_position_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_task: Some(7),
      member_position_edit_in_flight: True,
    )

  let #(next, fx) =
    position_edit.handle_saved_ok(
      model,
      TaskPosition(
        task_id: 7,
        user_id: 3,
        x: 44,
        y: 55,
        updated_at: "2026-06-01T10:00:00Z",
      ),
    )

  let assert False = next.member_position_edit_in_flight
  let assert None = next.member_position_edit_task
  let assert Ok(#(44, 55)) = dict.get(next.member_positions_by_task, 7)
  let assert True = fx == effect.none()
}

pub fn saved_error_clears_in_flight_and_sets_message_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_position_edit_in_flight: True,
      member_position_edit_error: None,
    )

  let #(next, fx) = position_edit.handle_saved_error(model, "boom")

  let assert False = next.member_position_edit_in_flight
  let assert Some("boom") = next.member_position_edit_error
  let assert True = fx == effect.none()
}

pub fn fetched_ok_replaces_positions_dict_test() {
  let model =
    member_positions.Model(
      ..member_positions.default_model(),
      member_positions_by_task: dict.from_list([#(1, #(1, 1))]),
    )

  let #(next, fx) =
    position_edit.handle_fetched_ok(model, [
      TaskPosition(
        task_id: 7,
        user_id: 3,
        x: 44,
        y: 55,
        updated_at: "2026-06-01T10:00:00Z",
      ),
    ])

  let assert Error(_) = dict.get(next.member_positions_by_task, 1)
  let assert Ok(#(44, 55)) = dict.get(next.member_positions_by_task, 7)
  let assert True = fx == effect.none()
}
