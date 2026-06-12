//// JSON presenters for task note endpoints.

import gleam/json
import scrumbringer_server/http/notes/presenters as note_presenters
import scrumbringer_server/services/task_notes_db

pub fn notes_response(values: List(task_notes_db.TaskNote)) -> json.Json {
  note_presenters.notes_response(values, note)
}

pub fn note(note: task_notes_db.TaskNote) -> json.Json {
  let task_notes_db.TaskNote(
    id: id,
    task_id: task_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
  ) = note

  json.object([
    #("id", json.int(id)),
    #("task_id", json.int(task_id)),
    #("user_id", json.int(user_id)),
    #("content", json.string(content)),
    #("created_at", json.string(created_at)),
  ])
}

pub fn note_response(value: task_notes_db.TaskNote) -> json.Json {
  note_presenters.note_response(value, note)
}
