import domain/task_status.{
  Available, Claimed, Completed, Ongoing, Taken, WorkAvailable, WorkClaimed,
  WorkCompleted, WorkOngoing,
}

pub fn parse_work_state_accepts_known_values_test() {
  let assert Ok(WorkAvailable) = task_status.parse_work_state("available")
  let assert Ok(WorkClaimed) = task_status.parse_work_state("claimed")
  let assert Ok(WorkOngoing) = task_status.parse_work_state("ongoing")
  let assert Ok(WorkCompleted) = task_status.parse_work_state("completed")
}

pub fn parse_work_state_rejects_unknown_values_test() {
  let assert Error(task_status.UnknownWorkState("blocked")) =
    task_status.parse_work_state("blocked")
}

pub fn parse_task_status_rejects_unknown_values_test() {
  let assert Error(task_status.UnknownTaskStatus("archived")) =
    task_status.parse_task_status("archived")
}

pub fn work_state_to_string_returns_wire_values_test() {
  let assert "available" = task_status.work_state_to_string(WorkAvailable)
  let assert "claimed" = task_status.work_state_to_string(WorkClaimed)
  let assert "ongoing" = task_status.work_state_to_string(WorkOngoing)
  let assert "completed" = task_status.work_state_to_string(WorkCompleted)
}

pub fn from_db_accepts_known_values_test() {
  let assert Ok(Available) = task_status.from_db("available", False)
  let assert Ok(Claimed(Taken)) = task_status.from_db("claimed", False)
  let assert Ok(Claimed(Ongoing)) = task_status.from_db("claimed", True)
  let assert Ok(Completed) = task_status.from_db("completed", False)
}

pub fn from_db_rejects_unknown_values_test() {
  let assert Error(task_status.UnknownTaskStatus("archived")) =
    task_status.from_db("archived", False)
}

pub fn parse_error_to_string_returns_stable_messages_test() {
  task_status.UnknownTaskStatus("archived")
  |> task_status.parse_error_to_string
  |> fn(message) {
    let assert "Unknown task status: archived" = message
  }

  task_status.UnknownWorkState("blocked")
  |> task_status.parse_error_to_string
  |> fn(message) {
    let assert "Unknown work state: blocked" = message
  }
}
