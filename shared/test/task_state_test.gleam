import domain/task_state
import domain/task_status
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
  let assert Ok(task_state.Claimed(
    42,
    "2026-01-01T00:00:00Z",
    task_status.Taken,
  )) =
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
    task_status.Ongoing,
  )) =
    task_state.from_db(
      "claimed",
      True,
      option.Some(42),
      option.Some("2026-01-01T00:00:00Z"),
      option.None,
    )
}

pub fn from_db_completed_test() {
  let assert Ok(task_state.Done("2026-01-01T00:00:00Z")) =
    task_state.from_db(
      "completed",
      False,
      option.None,
      option.None,
      option.Some("2026-01-01T00:00:00Z"),
    )
}

pub fn from_db_rejects_unknown_status_test() {
  let assert Error(task_state.UnknownStatus("archived")) =
    task_state.from_db("archived", False, option.None, option.None, option.None)
}

pub fn from_db_rejects_completed_with_claim_test() {
  let assert Error(task_state.DoneWithClaim) =
    task_state.from_db(
      "completed",
      False,
      option.Some(42),
      option.Some("2026-01-01T00:00:00Z"),
      option.Some("2026-01-02T00:00:00Z"),
    )
}
