import gleam/json

import domain/card/id as card_id
import domain/card/state as card_state
import domain/card/state_codec as card_state_codec
import domain/task/placement as task_placement
import domain/task/placement_codec as task_placement_codec
import domain/task/state as task_state
import domain/task/state_codec as task_state_codec
import domain/user/id as user_id

pub fn task_placement_root_pool_roundtrip_test() {
  let placement = task_placement.RootPool

  let encoded =
    placement
    |> task_placement_codec.to_json
    |> json.to_string

  let assert Ok(task_placement.RootPool) =
    json.parse(encoded, task_placement_codec.decoder())
}

pub fn task_placement_under_card_roundtrip_test() {
  let placement = task_placement.UnderCard(card_id.new(42))

  let encoded =
    placement
    |> task_placement_codec.to_json
    |> json.to_string

  let assert Ok(decoded) = json.parse(encoded, task_placement_codec.decoder())
  let assert True = decoded == placement
}

pub fn card_execution_state_roundtrip_test() {
  assert_card_state_roundtrip(card_state.Draft)

  assert_card_state_roundtrip(card_state.Active(
    activated_at: "2026-06-19T10:00:00Z",
    activated_by: user_id.new(7),
    source: card_state.DirectActivation,
  ))

  assert_card_state_roundtrip(card_state.Active(
    activated_at: "2026-06-19T10:00:00Z",
    activated_by: user_id.new(7),
    source: card_state.ActivatedByAncestor(card_id.new(1)),
  ))

  assert_card_state_roundtrip(card_state.Closed(
    reason: card_state.Rollup,
    closed_at: "2026-06-19T10:00:00Z",
    closed_by: card_state.ClosedBySystem,
  ))

  assert_card_state_roundtrip(card_state.Closed(
    reason: card_state.ManuallyClosed,
    closed_at: "2026-06-19T10:00:00Z",
    closed_by: card_state.ClosedByUser(user_id.new(7)),
  ))
}

pub fn task_execution_state_roundtrip_test() {
  assert_task_state_roundtrip(task_state.Available)

  assert_task_state_roundtrip(task_state.Claimed(
    claimed_by: user_id.new(7),
    claimed_at: "2026-06-19T10:00:00Z",
    mode: task_state.Taken,
  ))

  assert_task_state_roundtrip(task_state.Claimed(
    claimed_by: user_id.new(7),
    claimed_at: "2026-06-19T10:00:00Z",
    mode: task_state.Ongoing,
  ))

  assert_task_state_roundtrip(task_state.Closed(
    reason: task_state.Done,
    closed_at: "2026-06-19T10:00:00Z",
    closed_by: user_id.new(7),
  ))

  assert_task_state_roundtrip(task_state.Closed(
    reason: task_state.ManuallyClosed,
    closed_at: "2026-06-19T10:00:00Z",
    closed_by: user_id.new(7),
  ))

  assert_task_state_roundtrip(task_state.Closed(
    reason: task_state.ClosedByAncestor,
    closed_at: "2026-06-19T10:00:00Z",
    closed_by: user_id.new(7),
  ))
}

fn assert_card_state_roundtrip(state: card_state.CardExecutionState) {
  let encoded =
    state
    |> card_state_codec.to_json
    |> json.to_string

  let assert Ok(decoded) = json.parse(encoded, card_state_codec.decoder())
  let assert True = decoded == state
}

fn assert_task_state_roundtrip(state: task_state.TaskExecutionState) {
  let encoded =
    state
    |> task_state_codec.to_json
    |> json.to_string

  let assert Ok(decoded) = json.parse(encoded, task_state_codec.decoder())
  let assert True = decoded == state
}

pub fn completed_legacy_is_not_a_public_task_state_test() {
  let assert Error(_) =
    json.parse("{\"type\":\"completed\"}", task_state_codec.decoder())
}

pub fn unknown_task_execution_state_decoder_fails_test() {
  let assert Error(_) =
    json.parse("{\"type\":\"paused\"}", task_state_codec.decoder())
}

pub fn missing_required_state_fields_decoder_fails_test() {
  let assert Error(_) =
    json.parse(
      "{\"type\":\"claimed\",\"claimed_by\":7,\"mode\":\"taken\"}",
      task_state_codec.decoder(),
    )
}
