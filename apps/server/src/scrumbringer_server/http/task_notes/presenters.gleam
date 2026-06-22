//// JSON presenters for task note endpoints.

import domain/task.{type TaskNote, TaskNote}
import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/http/notes/presenters as note_presenters

pub fn notes_response(values: List(TaskNote)) -> json.Json {
  note_presenters.notes_response(values, note)
}

pub fn note(note: TaskNote) -> json.Json {
  let TaskNote(
    id: id,
    task_id: task_id,
    user_id: user_id,
    content: content,
    url: url,
    pinned: pinned,
    created_at: created_at,
    updated_at: updated_at,
  ) = note

  json.object([
    #("id", json.int(id)),
    #("task_id", json.int(task_id)),
    #("user_id", json.int(user_id)),
    #("content", json.string(content)),
    #("url", json_helpers.option_to_json(url, json.string)),
    #("pinned", json.bool(pinned)),
    #("created_at", json.string(created_at)),
    #("updated_at", json.string(updated_at)),
  ])
}

pub fn note_response(value: TaskNote) -> json.Json {
  note_presenters.note_response(value, note)
}
