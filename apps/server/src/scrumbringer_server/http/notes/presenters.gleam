//// Shared JSON wrappers for note endpoint presenters.

import gleam/json

pub fn notes_response(values: List(a), note_to_json: fn(a) -> json.Json) {
  json.object([#("notes", json.array(values, of: note_to_json))])
}

pub fn note_response(value: a, note_to_json: fn(a) -> json.Json) {
  json.object([#("note", note_to_json(value))])
}
