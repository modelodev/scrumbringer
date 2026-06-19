import gleam/json
import gleam/option.{None, Some}

import domain/task.{Task, TaskDependency}
import domain/task/codec
import domain/task_status
import domain/task_type.{TaskTypeInline}

pub fn task_due_date_roundtrip_test() {
  let body =
    "{\"id\":42,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Feature\",\"icon\":\"sparkles\"},\"ongoing_by\":null,\"title\":\"Ship deadline\",\"description\":null,\"priority\":3,\"status\":\"available\",\"created_by\":7,\"claimed_by\":null,\"claimed_at\":null,\"completed_at\":null,\"created_at\":\"2026-06-18T10:00:00Z\",\"version\":1,\"milestone_id\":null,\"card_id\":null,\"card_title\":null,\"card_color\":null,\"due_date\":\"2026-06-20\",\"has_new_notes\":false,\"blocked_count\":0,\"dependencies\":[]}"

  let assert Ok(Task(
    id: 42,
    task_type: TaskTypeInline(id: 2, name: "Feature", icon: "sparkles"),
    due_date: Some("2026-06-20"),
    ..,
  )) = json.parse(body, codec.task_decoder())
}

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
