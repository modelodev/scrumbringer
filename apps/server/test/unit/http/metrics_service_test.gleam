//// Tests work state derivation in metrics_service.

import domain/task_status.{
  WorkAvailable, WorkClaimed, WorkCompleted, WorkOngoing,
}
import gleeunit
import gleeunit/should
import scrumbringer_server/http/metrics_service

pub fn main() {
  gleeunit.main()
}

pub fn work_state_from_available_test() {
  metrics_service.work_state_from("available", False)
  |> should.equal(WorkAvailable)
}

pub fn work_state_from_claimed_test() {
  metrics_service.work_state_from("claimed", False)
  |> should.equal(WorkClaimed)
}

pub fn work_state_from_ongoing_test() {
  metrics_service.work_state_from("claimed", True)
  |> should.equal(WorkOngoing)
}

pub fn work_state_from_completed_test() {
  metrics_service.work_state_from("completed", False)
  |> should.equal(WorkCompleted)
}
