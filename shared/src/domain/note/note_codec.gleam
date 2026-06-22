//// Shared note JSON codec.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option

import domain/card/id as card_id
import domain/note/entity.{type Note, Note}
import domain/note/id as note_id
import domain/note/subject.{type NoteSubject, CardNoteSubject, TaskNoteSubject}
import domain/org_role
import domain/org_role/org_role_codec
import domain/project/id as project_id
import domain/project_role
import domain/project_role/project_role_codec
import domain/task/id as task_id
import domain/user/id as user_id

pub fn subject_decoder() -> decode.Decoder(NoteSubject) {
  use subject_type <- decode.field("subject_type", decode.string)
  use subject_id <- decode.field("subject_id", decode.int)
  case subject_type {
    "card" -> decode.success(CardNoteSubject(card_id.new(subject_id)))
    "task" -> decode.success(TaskNoteSubject(task_id.new(subject_id)))
    other ->
      decode.failure(
        CardNoteSubject(card_id.new(subject_id)),
        "note subject " <> other,
      )
  }
}

pub fn note_decoder() -> decode.Decoder(Note) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use subject <- decode.then(subject_decoder())
  use user_id <- decode.field("user_id", decode.int)
  use content <- decode.field("content", decode.string)
  use url <- decode.optional_field(
    "url",
    option.None,
    decode.optional(decode.string),
  )
  use pinned <- decode.field("pinned", decode.bool)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use author_email <- decode.field("author_email", decode.string)
  use author_project_role <- decode.optional_field(
    "author_project_role",
    option.None,
    decode.optional(project_role_codec.project_role_decoder()),
  )
  use author_org_role <- decode.field(
    "author_org_role",
    org_role_codec.org_role_decoder(),
  )

  decode.success(Note(
    id: note_id.new(id),
    project_id: project_id.new(project_id),
    subject: subject,
    user_id: user_id.new(user_id),
    content: content,
    url: url,
    pinned: pinned,
    created_at: created_at,
    updated_at: updated_at,
    author_email: author_email,
    author_project_role: author_project_role,
    author_org_role: author_org_role,
  ))
}

pub fn subject_to_json(subject: NoteSubject) -> List(#(String, json.Json)) {
  case subject {
    CardNoteSubject(note_card_id) -> [
      #("subject_type", json.string("card")),
      #("subject_id", json.int(card_id.to_int(note_card_id))),
    ]
    TaskNoteSubject(note_task_id) -> [
      #("subject_type", json.string("task")),
      #("subject_id", json.int(task_id.to_int(note_task_id))),
    ]
  }
}

pub fn to_json(note: Note) -> json.Json {
  let url = case note.url {
    option.Some(value) -> json.string(value)
    option.None -> json.null()
  }
  let author_project_role = case note.author_project_role {
    option.Some(role) -> project_role.to_json(role)
    option.None -> json.null()
  }

  let fields =
    [
      #("id", json.int(note_id.to_int(note.id))),
      #("project_id", json.int(project_id.to_int(note.project_id))),
    ]
    |> list.append(subject_to_json(note.subject))
    |> list.append([
      #("user_id", json.int(user_id.to_int(note.user_id))),
      #("content", json.string(note.content)),
      #("url", url),
      #("pinned", json.bool(note.pinned)),
      #("created_at", json.string(note.created_at)),
      #("updated_at", json.string(note.updated_at)),
      #("author_email", json.string(note.author_email)),
      #("author_project_role", author_project_role),
      #(
        "author_org_role",
        json.string(org_role.to_string(note.author_org_role)),
      ),
    ])

  json.object(fields)
}
