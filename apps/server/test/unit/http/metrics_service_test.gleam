//// Tests task execution-state derivation in metrics_service.

import domain/task/state as task_state
import gleam/option.{None, Some}
import gleeunit
import scrumbringer_server/http/metrics_service
import support/assertions as expect

pub fn main() {
  gleeunit.main()
}

pub fn execution_state_from_available_test() {
  metrics_service.execution_state_from("available", False, None, None, None)
  |> expect.equal(Ok(task_state.Available))
}

pub fn execution_state_from_claimed_test() {
  metrics_service.execution_state_from(
    "claimed",
    False,
    Some(7),
    Some("2026-06-25T10:00:00Z"),
    None,
  )
  |> expect.equal(
    Ok(task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-06-25T10:00:00Z",
      mode: task_state.Taken,
    )),
  )
}

pub fn execution_state_from_ongoing_test() {
  metrics_service.execution_state_from(
    "claimed",
    True,
    Some(7),
    Some("2026-06-25T10:00:00Z"),
    None,
  )
  |> expect.equal(
    Ok(task_state.Claimed(
      claimed_by: 7,
      claimed_at: "2026-06-25T10:00:00Z",
      mode: task_state.Ongoing,
    )),
  )
}

pub fn execution_state_from_closed_test() {
  metrics_service.execution_state_from(
    "closed",
    False,
    None,
    None,
    Some("2026-06-25T11:00:00Z"),
  )
  |> expect.equal(
    Ok(task_state.Closed(
      reason: task_state.Done,
      closed_at: "2026-06-25T11:00:00Z",
      closed_by: 0,
    )),
  )
}

pub fn execution_state_from_invalid_status_test() {
  let assert Error(metrics_service.InvalidTaskExecutionState("blocked")) =
    metrics_service.execution_state_from("blocked", False, None, None, None)
  Nil
}
