//// Tests work state derivation in metrics_service.

import domain/task_status.{
  WorkAvailable, WorkClaimed, WorkCompleted, WorkOngoing,
}
import gleeunit
import scrumbringer_server/http/metrics_service
import support/assertions as expect

pub fn main() {
  gleeunit.main()
}

pub fn work_state_from_available_test() {
  metrics_service.work_state_from("available", False)
  |> expect.equal(Ok(WorkAvailable))
}

pub fn work_state_from_claimed_test() {
  metrics_service.work_state_from("claimed", False)
  |> expect.equal(Ok(WorkClaimed))
}

pub fn work_state_from_ongoing_test() {
  metrics_service.work_state_from("claimed", True)
  |> expect.equal(Ok(WorkOngoing))
}

pub fn work_state_from_completed_test() {
  metrics_service.work_state_from("completed", False)
  |> expect.equal(Ok(WorkCompleted))
}

pub fn work_state_from_invalid_status_test() {
  let assert Error(metrics_service.InvalidTaskStatus("blocked")) =
    metrics_service.work_state_from("blocked", False)
  Nil
}
