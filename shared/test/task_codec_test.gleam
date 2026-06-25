import gleam/json
import gleam/option.{None, Some}

import domain/task.{Task, TaskDependency}
import domain/task/state as task_state
import domain/task/task_codec as codec
import domain/task_type.{TaskTypeInline}

pub fn task_due_date_roundtrip_test() {
  let body =
    "{\"id\":42,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Feature\",\"icon\":\"sparkles\"},\"ongoing_by\":null,\"title\":\"Ship deadline\",\"description\":null,\"priority\":3,\"status\":\"available\",\"created_by\":7,\"claimed_by\":null,\"claimed_at\":null,\"completed_at\":null,\"created_at\":\"2026-06-18T10:00:00Z\",\"version\":1,\"parent_card_id\":null,\"card_id\":null,\"card_title\":null,\"card_color\":null,\"due_date\":\"2026-06-20\",\"has_new_notes\":false,\"blocked_count\":0,\"dependencies\":[]}"

  let assert Ok(Task(
    id: 42,
    task_type: TaskTypeInline(id: 2, name: "Feature", icon: "sparkles"),
    due_date: Some("2026-06-20"),
    ..,
  )) = json.parse(body, codec.task_decoder())
}

pub fn task_decoder_rejects_invalid_due_date_test() {
  let body =
    "{\"id\":42,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Feature\",\"icon\":\"sparkles\"},\"ongoing_by\":null,\"title\":\"Ship deadline\",\"description\":null,\"priority\":3,\"status\":\"available\",\"created_by\":7,\"claimed_by\":null,\"claimed_at\":null,\"completed_at\":null,\"created_at\":\"2026-06-18T10:00:00Z\",\"version\":1,\"parent_card_id\":null,\"card_id\":null,\"card_title\":null,\"card_color\":null,\"due_date\":\"not-a-date\",\"has_new_notes\":false,\"blocked_count\":0,\"dependencies\":[]}"

  let assert Error(_) = json.parse(body, codec.task_decoder())
}

pub fn task_decoder_maps_public_completed_to_canonical_closed_test() {
  let body =
    "{\"id\":42,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Feature\",\"icon\":\"sparkles\"},\"ongoing_by\":null,\"title\":\"Ship deadline\",\"description\":null,\"priority\":3,\"status\":\"completed\",\"created_by\":7,\"claimed_by\":null,\"claimed_at\":null,\"completed_at\":\"2026-06-18T10:00:00Z\",\"created_at\":\"2026-06-17T10:00:00Z\",\"version\":2,\"parent_card_id\":null,\"card_id\":null,\"card_title\":null,\"card_color\":null,\"due_date\":null,\"has_new_notes\":false,\"blocked_count\":0,\"dependencies\":[]}"

  let assert Ok(Task(
    state: task_state.Closed(
      task_state.ClosedByClaimant,
      "2026-06-18T10:00:00Z",
      0,
    ),
    ..,
  )) = json.parse(body, codec.task_decoder())
}

pub fn task_dependency_decoder_accepts_known_status_test() {
  let assert Ok(TaskDependency(
    depends_on_task_id: 42,
    title: "Design",
    state: task_state.Claimed(7, "2026-06-18T10:00:00Z", task_state.Taken),
    claimed_by: None,
  )) =
    json.parse(
      "{\"task_id\":42,\"title\":\"Design\",\"status\":\"claimed\",\"claimed_by_user_id\":7,\"claimed_at\":\"2026-06-18T10:00:00Z\",\"is_ongoing\":false}",
      codec.task_dependency_decoder(),
    )
}

pub fn task_dependency_decoder_maps_public_completed_to_canonical_closed_test() {
  let assert Ok(TaskDependency(
    depends_on_task_id: 42,
    title: "Design",
    state: task_state.Closed(
      task_state.ClosedByClaimant,
      "2026-06-18T10:00:00Z",
      0,
    ),
    claimed_by: None,
  )) =
    json.parse(
      "{\"task_id\":42,\"title\":\"Design\",\"status\":\"completed\",\"completed_at\":\"2026-06-18T10:00:00Z\"}",
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
