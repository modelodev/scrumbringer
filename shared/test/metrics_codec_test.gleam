import gleam/json
import gleam/option.{Some}

import domain/metrics.{MetricsProjectTask}
import domain/metrics/metrics_codec as codec
import domain/task.{Task}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}

pub fn metrics_project_task_accepts_date_only_due_date_test() {
  let assert Ok(MetricsProjectTask(
    task: Task(
      id: 42,
      task_type: TaskTypeInline(id: 2, name: "Feature", icon: "sparkles"),
      due_date: Some("2026-06-20"),
      ..,
    ),
    claim_count: 2,
    release_count: 1,
    close_count: 0,
    ..,
  )) =
    json.parse(
      metrics_task_body("\"2026-06-20\""),
      codec.metrics_project_task_decoder(),
    )
}

pub fn metrics_project_task_rejects_invalid_due_date_test() {
  let assert Error(_) =
    json.parse(
      metrics_task_body("\"2026-02-31\""),
      codec.metrics_project_task_decoder(),
    )
}

pub fn metrics_project_task_uses_work_state_for_ongoing_claimed_tasks_test() {
  let assert Ok(MetricsProjectTask(
    task: Task(
      state: task_state.Claimed(
        claimed_by: 7,
        claimed_at: "2026-06-18T10:00:00Z",
        mode: task_state.Ongoing,
      ),
      ..,
    ),
    ..,
  )) =
    json.parse(
      metrics_task_body_with_state(
        "\"2026-06-20\"",
        "\"claimed\"",
        "\"ongoing\"",
        "7",
        "\"2026-06-18T10:00:00Z\"",
      ),
      codec.metrics_project_task_decoder(),
    )
}

fn metrics_task_body(due_date: String) -> String {
  metrics_task_body_with_state(
    due_date,
    "\"available\"",
    "\"available\"",
    "null",
    "null",
  )
}

fn metrics_task_body_with_state(
  due_date: String,
  status: String,
  work_state: String,
  claimed_by: String,
  claimed_at: String,
) -> String {
  "{\"id\":42,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Feature\",\"icon\":\"sparkles\"},\"ongoing_by\":null,\"title\":\"Ship deadline\",\"description\":null,\"priority\":3,\"status\":"
  <> status
  <> ",\"work_state\":"
  <> work_state
  <> ",\"created_by\":7,\"claimed_by\":"
  <> claimed_by
  <> ",\"claimed_at\":"
  <> claimed_at
  <> ",\"closed_at\":null,\"created_at\":\"2026-06-18T10:00:00Z\",\"due_date\":"
  <> due_date
  <> ",\"version\":1,\"claim_count\":2,\"release_count\":1,\"close_count\":0,\"first_claim_at\":null}"
}
