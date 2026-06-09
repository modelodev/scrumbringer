//// Payload and query parsing for task position endpoints.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import scrumbringer_server/http/query as query_params

pub type PositionPayload {
  PositionPayload(x: Int, y: Int)
}

pub type DecodeError {
  InvalidJson
}

pub type ProjectFilterError {
  InvalidProjectId
}

pub fn decode_position(data: Dynamic) -> Result(PositionPayload, DecodeError) {
  let decoder = {
    use x <- decode.field("x", decode.int)
    use y <- decode.field("y", decode.int)
    decode.success(PositionPayload(x: x, y: y))
  }

  decode.run(data, decoder)
  |> result.map_error(fn(_) { InvalidJson })
}

pub fn parse_project_id_filter(
  query: List(#(String, String)),
) -> Result(Int, ProjectFilterError) {
  case query_params.single_value(query, "project_id") {
    Ok(None) -> Ok(0)
    Ok(Some(value)) ->
      int.parse(value)
      |> result.map_error(fn(_) { InvalidProjectId })
    Error(_) -> Error(InvalidProjectId)
  }
}
