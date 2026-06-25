import gleam/json
import gleam/option.{Some}

import domain/metrics.{MetricsProjectTask}
import domain/metrics/metrics_codec as codec
import domain/task.{Task}
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
    complete_count: 0,
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

fn metrics_task_body(due_date: String) -> String {
  "{\"id\":42,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Feature\",\"icon\":\"sparkles\"},\"ongoing_by\":null,\"title\":\"Ship deadline\",\"description\":null,\"priority\":3,\"status\":\"available\",\"created_by\":7,\"claimed_by\":null,\"claimed_at\":null,\"completed_at\":null,\"created_at\":\"2026-06-18T10:00:00Z\",\"due_date\":"
  <> due_date
  <> ",\"version\":1,\"claim_count\":2,\"release_count\":1,\"complete_count\":0,\"first_claim_at\":null}"
}
