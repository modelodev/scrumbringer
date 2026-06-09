import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/string

import scrumbringer_server/http/api
import scrumbringer_server/http/notes/mutations
import scrumbringer_server/http/notes/payloads
import support/assertions as expect
import wisp/simulate

pub fn decode_note_payload_test() {
  let assert Ok(dynamic) =
    json.parse("{\"content\":\"plain note\"}", decode.dynamic)

  let assert Ok(payloads.NotePayload(content: "plain note")) =
    payloads.decode_note(dynamic)
}

pub fn decode_note_payload_rejects_missing_content_test() {
  let assert Ok(dynamic) = json.parse("{}", decode.dynamic)

  let assert Error(payloads.InvalidJson) = payloads.decode_note(dynamic)
}

pub fn decode_note_payload_keeps_content_unchanged_test() {
  let assert Ok(dynamic) =
    json.parse("{\"content\":\"  surrounding spaces  \"}", decode.dynamic)

  let assert Ok(payloads.NotePayload(content: "  surrounding spaces  ")) =
    payloads.decode_note(dynamic)
}

pub fn with_note_payload_valid_request_calls_handler_test() {
  let req =
    simulate.request(http.Post, "/notes")
    |> request.set_cookie("sb_csrf", "token")
    |> request.set_header("x-csrf", "token")
    |> simulate.json_body(json.object([#("content", json.string("hello"))]))

  let res =
    mutations.with_note_payload(req, "42", fn(parent_id, payload) {
      api.ok(
        json.object([
          #("parent_id", json.int(parent_id)),
          #("content", json.string(payload.content)),
        ]),
      )
    })

  expect.expect_status(res, 200)
  let body = simulate.read_body(res)
  string.contains(body, "\"parent_id\":42") |> expect.is_true
  string.contains(body, "\"content\":\"hello\"") |> expect.is_true
}

pub fn with_note_payload_invalid_json_returns_validation_error_test() {
  let req =
    simulate.request(http.Post, "/notes")
    |> request.set_cookie("sb_csrf", "token")
    |> request.set_header("x-csrf", "token")
    |> simulate.json_body(json.object([]))

  let res =
    mutations.with_note_payload(req, "42", fn(_, _) { api.ok(json.object([])) })

  expect.expect_status(res, 400)
  simulate.read_body(res)
  |> string.contains("VALIDATION_ERROR")
  |> expect.is_true
}
