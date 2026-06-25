import domain/task/state as task_state
import gleam/option

pub fn from_db_available_test() {
  let assert Ok(task_state.Available) =
    task_state.from_db(
      "available",
      False,
      option.None,
      option.None,
      option.None,
    )
}

pub fn from_db_claimed_test() {
  let assert Ok(task_state.Claimed(42, "2026-01-01T00:00:00Z", task_state.Taken)) =
    task_state.from_db(
      "claimed",
      False,
      option.Some(42),
      option.Some("2026-01-01T00:00:00Z"),
      option.None,
    )
}

pub fn from_db_ongoing_test() {
  let assert Ok(task_state.Claimed(
    42,
    "2026-01-01T00:00:00Z",
    task_state.Ongoing,
  )) =
    task_state.from_db(
      "claimed",
      True,
      option.Some(42),
      option.Some("2026-01-01T00:00:00Z"),
      option.None,
    )
}

pub fn from_db_rejects_completed_status_test() {
  let assert Error(task_state.UnknownStatus("completed")) =
    task_state.from_db(
      "completed",
      False,
      option.None,
      option.None,
      option.Some("2026-01-01T00:00:00Z"),
    )
}

pub fn from_db_closed_test() {
  let assert Ok(task_state.Closed(
    task_state.ClosedByClaimant,
    "2026-01-01T00:00:00Z",
    0,
  )) =
    task_state.from_db(
      "closed",
      False,
      option.None,
      option.None,
      option.Some("2026-01-01T00:00:00Z"),
    )
}

pub fn to_db_closed_uses_canonical_closed_string_test() {
  let assert #(
    "closed",
    False,
    option.None,
    option.None,
    option.Some("2026-01-01T00:00:00Z"),
  ) =
    task_state.to_db(task_state.Closed(
      task_state.ClosedByClaimant,
      "2026-01-01T00:00:00Z",
      7,
    ))
}

pub fn from_db_rejects_unknown_status_test() {
  let assert Error(task_state.UnknownStatus("archived")) =
    task_state.from_db("archived", False, option.None, option.None, option.None)
}

pub fn from_db_rejects_completed_with_claim_test() {
  let assert Error(task_state.UnknownStatus("completed")) =
    task_state.from_db(
      "completed",
      False,
      option.Some(42),
      option.Some("2026-01-01T00:00:00Z"),
      option.Some("2026-01-02T00:00:00Z"),
    )
}
