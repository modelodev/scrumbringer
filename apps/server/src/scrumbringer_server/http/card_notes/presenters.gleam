//// JSON presenters for card note endpoints.

import domain/org_role
import domain/project_role
import gleam/json
import helpers/json as json_helpers
import scrumbringer_server/http/notes/presenters as note_presenters
import scrumbringer_server/services/card_notes_db

pub fn notes_response(values: List(card_notes_db.CardNote)) -> json.Json {
  note_presenters.notes_response(values, note)
}

pub fn note(note: card_notes_db.CardNote) -> json.Json {
  let card_notes_db.CardNote(
    id: id,
    card_id: card_id,
    user_id: user_id,
    content: content,
    created_at: created_at,
    author_email: author_email,
    author_project_role: author_project_role,
    author_org_role: author_org_role,
  ) = note

  json.object([
    #("id", json.int(id)),
    #("card_id", json.int(card_id)),
    #("user_id", json.int(user_id)),
    #("content", json.string(content)),
    #("created_at", json.string(created_at)),
    #("author_email", json.string(author_email)),
    #(
      "author_project_role",
      json_helpers.option_to_json(author_project_role, fn(role) {
        json.string(project_role.to_string(role))
      }),
    ),
    #("author_org_role", json.string(org_role.to_string(author_org_role))),
  ])
}

pub fn note_response(value: card_notes_db.CardNote) -> json.Json {
  note_presenters.note_response(value, note)
}
