//// Shared mutation helpers for note endpoints.

import gleam/result
import scrumbringer_server/http/api
import scrumbringer_server/http/csrf
import scrumbringer_server/http/notes/payload_responses
import scrumbringer_server/http/notes/payloads
import wisp

pub fn with_note_payload(
  req: wisp.Request,
  parent_id: String,
  handle_payload: fn(Int, payloads.NotePayload) -> wisp.Response,
) -> wisp.Response {
  case csrf.require_csrf(req) {
    Error(resp) -> resp

    Ok(Nil) -> {
      case api.parse_id(parent_id) {
        Error(resp) -> resp

        Ok(parent_id) -> {
          use data <- wisp.require_json(req)

          case decode_note_payload(data) {
            Error(resp) -> resp
            Ok(payload) -> handle_payload(parent_id, payload)
          }
        }
      }
    }
  }
}

fn decode_note_payload(data) -> Result(payloads.NotePayload, wisp.Response) {
  payloads.decode_note(data)
  |> result.map_error(payload_responses.decode_error)
}
