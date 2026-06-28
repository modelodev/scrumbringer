//// Shared JSON wrappers for note endpoint presenters.

import domain/note/entity.{type Note}
import domain/note/note_codec
import gleam/json

pub fn notes_response(values: List(Note)) -> json.Json {
  json.object([#("notes", json.array(values, of: note))])
}

pub fn note(value: Note) -> json.Json {
  note_codec.to_json(value)
}

pub fn note_response(value: Note) -> json.Json {
  json.object([#("note", note(value))])
}
