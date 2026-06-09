//// JSON payload decoders for work session endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result

pub type TaskIdPayload {
  TaskIdPayload(task_id: Int)
}

pub type DecodeError {
  InvalidJson
}

pub fn decode_task_id(data: Dynamic) -> Result(TaskIdPayload, DecodeError) {
  let decoder = {
    use task_id <- decode.field("task_id", decode.int)
    decode.success(TaskIdPayload(task_id: task_id))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { InvalidJson })
}
