import gleam/option.{None, Some}

import domain/api_error.{type ApiError, ApiError}
import domain/note/entity.{type Note, Note}
import domain/note/id as note_id
import domain/note/subject.{TaskNoteSubject}
import domain/org_role
import domain/project/id as project_id
import domain/remote
import domain/task/id as task_id
import domain/user/id as user_id
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/features/tasks/note_state

fn sample_note() -> Note {
  Note(
    id: note_id.new(10),
    project_id: project_id.new(1),
    subject: TaskNoteSubject(task_id.new(42)),
    user_id: user_id.new(7),
    content: "Reviewed",
    url: None,
    pinned: False,
    created_at: "2026-03-20T14:00:00Z",
    updated_at: "2026-03-20T14:00:00Z",
    author_email: "user@example.com",
    author_project_role: None,
    author_org_role: org_role.Member,
  )
}

fn sample_error() -> ApiError {
  ApiError(status: 500, code: "ERR", message: "boom")
}

pub fn note_state_loaded_and_failed_set_remote_notes_test() {
  let note = sample_note()
  let err = sample_error()

  let loaded = note_state.loaded(member_notes.default_model(), [note])
  let failed = note_state.failed(member_notes.default_model(), err)

  let assert True = loaded.member_notes == remote.Loaded([note])
  let assert True = failed.member_notes == remote.Failed(err)
}

pub fn note_state_content_and_dialog_transitions_test() {
  let changed =
    note_state.content_changed(member_notes.default_model(), "draft")
  let opened =
    note_state.open_dialog(
      member_notes.Model(..changed, member_note_error: Some("old")),
    )
  let closed =
    note_state.close_dialog(
      member_notes.Model(
        ..opened,
        member_note_content: "draft",
        member_note_error: Some("old"),
      ),
    )

  let assert "draft" = changed.member_note_content
  let assert dialog_mode.DialogCreate = opened.member_note_dialog_mode
  let assert None = opened.member_note_error
  let assert dialog_mode.DialogClosed = closed.member_note_dialog_mode
  let assert "" = closed.member_note_content
  let assert None = closed.member_note_error
}

pub fn note_state_submit_transitions_test() {
  let invalid =
    note_state.submit_invalid(member_notes.default_model(), "Required")
  let ready =
    note_state.submit_ready(
      member_notes.Model(..invalid, member_note_in_flight: False),
    )

  let assert Some("Required") = invalid.member_note_error
  let assert True = ready.member_note_in_flight
  let assert None = ready.member_note_error
}

pub fn note_state_added_prepends_note_and_closes_dialog_test() {
  let previous = Note(..sample_note(), id: note_id.new(9), content: "Previous")
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes: remote.Loaded([previous]),
      member_note_in_flight: True,
      member_note_content: "draft",
      member_note_dialog_mode: dialog_mode.DialogCreate,
    )

  let next = note_state.added(model, sample_note())
  let expected = remote.Loaded([sample_note(), previous])

  let assert True = next.member_notes == expected
  let assert False = next.member_note_in_flight
  let assert "" = next.member_note_content
  let assert dialog_mode.DialogClosed = next.member_note_dialog_mode
}

pub fn note_state_add_failed_stops_in_flight_and_sets_error_test() {
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_note_in_flight: True,
    )

  let next = note_state.add_failed(model, sample_error())

  let assert False = next.member_note_in_flight
  let assert Some("boom") = next.member_note_error
}

pub fn note_state_pin_transitions_replace_note_test() {
  let previous = sample_note()
  let updated =
    Note(..previous, pinned: True, updated_at: "2026-03-20T15:00:00Z")
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes: remote.Loaded([previous]),
    )

  let started = note_state.pin_started(model, note_id.to_int(previous.id))
  let next = note_state.pinned(started, updated)

  let assert True =
    started.member_note_pin_in_flight == Some(note_id.to_int(previous.id))
  let assert True = next.member_notes == remote.Loaded([updated])
  let assert None = next.member_note_pin_in_flight
}

pub fn note_state_pin_failed_clears_in_flight_and_sets_error_test() {
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_note_pin_in_flight: Some(10),
    )

  let next = note_state.pin_failed(model, sample_error())

  let assert None = next.member_note_pin_in_flight
  let assert Some("boom") = next.member_note_error
}
