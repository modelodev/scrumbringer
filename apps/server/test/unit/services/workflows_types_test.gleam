//// Tests compatibility helpers in workflows/types.

import domain/task_status.{Available, Claimed, Completed, Ongoing, Taken}
import gleeunit
import gleeunit/should
import scrumbringer_server/services/workflows/types

pub fn main() {
  gleeunit.main()
}

pub fn parse_task_status_accepts_known_values_test() {
  types.parse_task_status("available")
  |> should.equal(Ok(Available))
}

pub fn parse_task_status_rejects_unknown_values_test() {
  types.parse_task_status("invalid")
  |> should.equal(Error(Nil))
}

pub fn task_status_to_db_maps_claimed_states_test() {
  types.task_status_to_db(Claimed(Taken))
  |> should.equal("claimed")

  types.task_status_to_db(Claimed(Ongoing))
  |> should.equal("claimed")

  types.task_status_to_db(Completed)
  |> should.equal("completed")
}
