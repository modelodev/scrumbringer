import domain/task_status.{
  Available, Claimed, Closed, Ongoing, Taken, WorkAvailable, WorkClaimed,
  WorkClosed, WorkOngoing,
}

pub fn parse_work_state_accepts_known_values_test() {
  let assert Ok(WorkAvailable) = task_status.parse_work_state("available")
  let assert Ok(WorkClaimed) = task_status.parse_work_state("claimed")
  let assert Ok(WorkOngoing) = task_status.parse_work_state("ongoing")
  let assert Ok(WorkClosed) = task_status.parse_work_state("closed")
}

pub fn parse_work_state_rejects_unknown_values_test() {
  let assert Error(task_status.UnknownWorkState("blocked")) =
    task_status.parse_work_state("blocked")
}

pub fn parse_task_status_rejects_unknown_values_test() {
  let assert Error(task_status.UnknownTaskPhase("archived")) =
    task_status.parse_task_status("archived")
}

pub fn parse_task_status_rejects_ongoing_status_test() {
  let assert Error(task_status.UnknownTaskPhase("ongoing")) =
    task_status.parse_task_status("ongoing")
}

pub fn work_state_to_string_returns_wire_values_test() {
  let assert "available" = task_status.work_state_to_string(WorkAvailable)
  let assert "claimed" = task_status.work_state_to_string(WorkClaimed)
  let assert "ongoing" = task_status.work_state_to_string(WorkOngoing)
  let assert "closed" = task_status.work_state_to_string(WorkClosed)
}

pub fn task_status_to_string_keeps_ongoing_as_claimed_phase_test() {
  let assert "available" = task_status.task_status_to_string(Available)
  let assert "claimed" = task_status.task_status_to_string(Claimed(Taken))
  let assert "claimed" = task_status.task_status_to_string(Claimed(Ongoing))
  let assert "closed" = task_status.task_status_to_string(Closed)
}
