import domain/task/state as task_state
import domain/task/task_codec
import gleam/dynamic/decode
import gleam/json

fn assert_error(result: Result(a, b)) {
  let assert Error(_) = result
}

pub fn task_decoder_accepts_enriched_task_type_and_work_state_test() {
  let body =
    "{\"id\":1,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Bug\",\"icon\":\"bug-ant\"},\"title\":\"T\",\"description\":null,\"priority\":3,\"status\":\"claimed\",\"work_state\":\"ongoing\",\"created_by\":1,\"claimed_by\":1,\"claimed_at\":\"2026-01-01T00:00:00Z\",\"closed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\",\"version\":1}"

  let assert Ok(dynamic) = json.parse(from: body, using: decode.dynamic)

  let result = decode.run(dynamic, task_codec.task_decoder())

  let assert Ok(task) = result
  let assert 1 = task.id
  let assert 2 = task.type_id
  let assert "Bug" = task.task_type.name
  let assert "bug-ant" = task.task_type.icon
  let assert "T" = task.title
  let assert task_state.Claimed(mode: task_state.Ongoing, ..) = task.state
}

pub fn task_decoder_rejects_invalid_status_and_work_state_test() {
  let body =
    "{\"id\":1,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Bug\",\"icon\":\"bug-ant\"},\"title\":\"T\",\"description\":null,\"priority\":3,\"status\":\"weird\",\"work_state\":\"unknown\",\"created_by\":1,\"claimed_by\":null,\"claimed_at\":null,\"closed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\",\"version\":1}"

  let assert Ok(dynamic) = json.parse(from: body, using: decode.dynamic)
  let result = decode.run(dynamic, task_codec.task_decoder())

  assert_error(result)
}

pub fn task_decoder_rejects_missing_id_test() {
  let body =
    "{\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Bug\",\"icon\":\"bug-ant\"},\"title\":\"T\",\"description\":null,\"priority\":3,\"status\":\"claimed\",\"work_state\":\"ongoing\",\"created_by\":1,\"claimed_by\":1,\"claimed_at\":\"2026-01-01T00:00:00Z\",\"closed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\",\"version\":1}"

  let assert Ok(dynamic) = json.parse(from: body, using: decode.dynamic)
  let result = decode.run(dynamic, task_codec.task_decoder())

  assert_error(result)
}
