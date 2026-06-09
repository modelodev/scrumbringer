//// Shared helpers for JSON request payload boundaries.

import gleam/dynamic.{type Dynamic}
import scrumbringer_server/http/api
import scrumbringer_server/http/csrf
import wisp

pub fn with_response(
  req: wisp.Request,
  decode_payload: fn(Dynamic) -> Result(payload, wisp.Response),
  handle_payload: fn(payload) -> wisp.Response,
) -> wisp.Response {
  use data <- wisp.require_json(req)

  case decode_payload(data) {
    Error(resp) -> resp
    Ok(payload) -> handle_payload(payload)
  }
}

pub fn with_csrf(
  req: wisp.Request,
  decode_payload: fn(Dynamic) -> Result(payload, error),
  handle_payload: fn(payload) -> wisp.Response,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp

    Ok(Nil) -> {
      use data <- wisp.require_json(req)

      case decode_payload(data) {
        Error(_) -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")
        Ok(payload) -> handle_payload(payload)
      }
    }
  }
}
