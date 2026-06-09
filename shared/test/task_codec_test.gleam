import gleam/json
import gleam/option.{None}

import domain/task.{TaskDependency}
import domain/task/codec
import domain/task_status

pub fn task_dependency_decoder_accepts_known_status_test() {
  let assert Ok(TaskDependency(
    depends_on_task_id: 42,
    title: "Design",
    status: task_status.Claimed(task_status.Taken),
    claimed_by: None,
  )) =
    json.parse(
      "{\"task_id\":42,\"title\":\"Design\",\"status\":\"claimed\"}",
      codec.task_dependency_decoder(),
    )
}

pub fn task_dependency_decoder_rejects_unknown_status_test() {
  let assert Error(_) =
    json.parse(
      "{\"task_id\":42,\"title\":\"Design\",\"status\":\"blocked\"}",
      codec.task_dependency_decoder(),
    )
}
