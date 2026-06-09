//// HTTP responses for note payload decode errors.

import scrumbringer_server/http/api
import scrumbringer_server/http/notes/payloads
import wisp

pub fn decode_error(error: payloads.DecodeError) -> wisp.Response {
  case error {
    payloads.InvalidJson -> api.error(400, "VALIDATION_ERROR", "Invalid JSON")
  }
}
