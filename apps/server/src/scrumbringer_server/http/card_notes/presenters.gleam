//// JSON presenters for card note endpoints.

import domain/note/entity.{type Note}
import domain/note/note_codec
import gleam/json
import scrumbringer_server/http/notes/presenters as note_presenters

pub fn notes_response(values: List(Note)) -> json.Json {
  note_presenters.notes_response(values, note)
}

pub fn note(note: Note) -> json.Json {
  note_codec.to_json(note)
}

pub fn note_response(value: Note) -> json.Json {
  note_presenters.note_response(value, note)
}
