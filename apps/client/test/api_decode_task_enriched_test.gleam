import domain/task.{Task}
import domain/task_status
import gleam/dynamic/decode
import gleam/json
import gleeunit/should
import scrumbringer_client/api/tasks as api_tasks

pub fn task_decoder_accepts_enriched_task_type_and_work_state_test() {
  let body =
    "{\"id\":1,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Bug\",\"icon\":\"bug-ant\"},\"title\":\"T\",\"description\":null,\"priority\":3,\"status\":\"claimed\",\"work_state\":\"ongoing\",\"created_by\":1,\"claimed_by\":1,\"claimed_at\":\"2026-01-01T00:00:00Z\",\"completed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\",\"version\":1}"

  let assert Ok(dynamic) = json.parse(from: body, using: decode.dynamic)

  let result = decode.run(dynamic, api_tasks.task_decoder())

  result |> should.be_ok
}

pub fn task_decoder_falls_back_on_invalid_status_and_work_state_test() {
  let body =
    "{\"id\":1,\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Bug\",\"icon\":\"bug-ant\"},\"title\":\"T\",\"description\":null,\"priority\":3,\"status\":\"weird\",\"work_state\":\"unknown\",\"created_by\":1,\"claimed_by\":null,\"claimed_at\":null,\"completed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\",\"version\":1}"

  let assert Ok(dynamic) = json.parse(from: body, using: decode.dynamic)
  let result = decode.run(dynamic, api_tasks.task_decoder())

  let assert Ok(task) = result
  let Task(status: status, work_state: work_state, ..) = task

  status |> should.equal(task_status.Available)
  work_state |> should.equal(task_status.WorkClaimed)
}

pub fn task_decoder_rejects_missing_id_test() {
  let body =
    "{\"project_id\":1,\"type_id\":2,\"task_type\":{\"id\":2,\"name\":\"Bug\",\"icon\":\"bug-ant\"},\"title\":\"T\",\"description\":null,\"priority\":3,\"status\":\"claimed\",\"work_state\":\"ongoing\",\"created_by\":1,\"claimed_by\":1,\"claimed_at\":\"2026-01-01T00:00:00Z\",\"completed_at\":null,\"created_at\":\"2026-01-01T00:00:00Z\",\"version\":1}"

  let assert Ok(dynamic) = json.parse(from: body, using: decode.dynamic)
  let result = decode.run(dynamic, api_tasks.task_decoder())

  result |> should.be_error
}
