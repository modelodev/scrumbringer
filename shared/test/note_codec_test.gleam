import gleam/json
import gleam/option

import domain/card/id as card_id
import domain/note/entity.{Note}
import domain/note/id as note_id
import domain/note/note_codec
import domain/note/subject.{CardNoteSubject, TaskNoteSubject}
import domain/org_role
import domain/project/id as project_id
import domain/project_role
import domain/task/id as task_id
import domain/user/id as user_id

pub fn note_decoder_decodes_card_subject_and_pinned_url_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"subject_type\":\"card\",\"subject_id\":10,\"user_id\":42,\"content\":\"Scope agreed\",\"url\":\"https://example.com/spec\",\"pinned\":true,\"created_at\":\"2026-06-22T10:00:00Z\",\"updated_at\":\"2026-06-22T10:05:00Z\",\"author_email\":\"ana@example.com\",\"author_project_role\":\"manager\",\"author_org_role\":\"admin\"}"

  let assert Ok(Note(
    id: decoded_id,
    project_id: decoded_project_id,
    subject: CardNoteSubject(decoded_card_id),
    user_id: decoded_user_id,
    content: "Scope agreed",
    url: option.Some("https://example.com/spec"),
    pinned: True,
    created_at: "2026-06-22T10:00:00Z",
    updated_at: "2026-06-22T10:05:00Z",
    author_email: "ana@example.com",
    author_project_role: option.Some(project_role.Manager),
    author_org_role: org_role.Admin,
  )) = json.parse(body, note_codec.note_decoder())

  let assert 1 = note_id.to_int(decoded_id)
  let assert 2 = project_id.to_int(decoded_project_id)
  let assert 10 = card_id.to_int(decoded_card_id)
  let assert 42 = user_id.to_int(decoded_user_id)
}

pub fn note_decoder_decodes_task_subject_without_url_or_project_role_test() {
  let body =
    "{\"id\":2,\"project_id\":2,\"subject_type\":\"task\",\"subject_id\":20,\"user_id\":43,\"content\":\"Check logs\",\"url\":null,\"pinned\":false,\"created_at\":\"2026-06-22T11:00:00Z\",\"updated_at\":\"2026-06-22T11:00:00Z\",\"author_email\":\"luis@example.com\",\"author_project_role\":null,\"author_org_role\":\"member\"}"

  let assert Ok(Note(
    subject: TaskNoteSubject(decoded_task_id),
    url: option.None,
    pinned: False,
    author_project_role: option.None,
    author_org_role: org_role.Member,
    ..,
  )) = json.parse(body, note_codec.note_decoder())

  let assert 20 = task_id.to_int(decoded_task_id)
}

pub fn note_decoder_rejects_invalid_subject_type_test() {
  let body =
    "{\"id\":1,\"project_id\":2,\"subject_type\":\"milestone\",\"subject_id\":10,\"user_id\":42,\"content\":\"Scope agreed\",\"url\":null,\"pinned\":true,\"created_at\":\"2026-06-22T10:00:00Z\",\"updated_at\":\"2026-06-22T10:05:00Z\",\"author_email\":\"ana@example.com\",\"author_project_role\":\"manager\",\"author_org_role\":\"admin\"}"

  let assert Error(_) = json.parse(body, note_codec.note_decoder())
}

pub fn note_to_json_roundtrips_task_subject_test() {
  let note = Note(
    id: note_id.new(9),
    project_id: project_id.new(2),
    subject: TaskNoteSubject(task_id.new(20)),
    user_id: user_id.new(43),
    content: "Check logs",
    url: option.None,
    pinned: True,
    created_at: "2026-06-22T11:00:00Z",
    updated_at: "2026-06-22T11:10:00Z",
    author_email: "luis@example.com",
    author_project_role: option.Some(project_role.Member),
    author_org_role: org_role.Member,
  )

  let encoded = note_codec.to_json(note) |> json.to_string
  let assert Ok(Note(subject: TaskNoteSubject(decoded_task_id), pinned: True, ..)) =
    json.parse(encoded, note_codec.note_decoder())
  let assert 20 = task_id.to_int(decoded_task_id)
}
