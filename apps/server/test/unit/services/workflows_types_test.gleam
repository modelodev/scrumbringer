//// Tests compatibility helpers in workflows/types.

import domain/task_status.{
  Available, Claimed, Completed, Ongoing, Taken, parse_task_status, to_db_status,
}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn parse_task_status_accepts_known_values_test() {
  parse_task_status("available")
  |> should.equal(Ok(Available))
}

pub fn parse_task_status_rejects_unknown_values_test() {
  parse_task_status("invalid")
  |> should.equal(Error("Unknown task status: invalid"))
}

pub fn task_status_to_db_maps_claimed_states_test() {
  to_db_status(Claimed(Taken))
  |> should.equal("claimed")

  to_db_status(Claimed(Ongoing))
  |> should.equal("claimed")

  to_db_status(Completed)
  |> should.equal("completed")
}
