import gleam/option.{None, Some}
import lustre/effect

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
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/notes_update

fn note_context() -> notes_update.Context(Nil) {
  notes_update.Context(
    content_required: "Content required",
    note_added: "Note added",
    on_note_added: fn(_result) { Nil },
    on_note_deleted: fn(_note_id, _result) { Nil },
    on_note_pinned: fn(_note_id, _result) { Nil },
    on_notes_fetched: fn(_result) { Nil },
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

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

pub fn local_note_content_changed_updates_content_test() {
  let assert Some(notes_update.Update(next, fx, notes_update.NoAuthCheck)) =
    notes_update.try_update(
      member_notes.default_model(),
      pool_messages.MemberNoteContentChanged("draft"),
      note_context(),
    )

  let assert "draft" = next.member_note_content
  let assert True = fx == effect.none()
}

pub fn local_note_dialog_opened_and_closed_updates_dialog_state_test() {
  let assert Some(notes_update.Update(opened, open_fx, notes_update.NoAuthCheck)) =
    notes_update.try_update(
      member_notes.Model(
        ..member_notes.default_model(),
        member_note_error: Some("old"),
      ),
      pool_messages.MemberNoteDialogOpened,
      note_context(),
    )

  let assert dialog_mode.DialogCreate = opened.member_note_dialog_mode
  let assert None = opened.member_note_error
  let assert True = open_fx == effect.none()

  let assert Some(notes_update.Update(
    closed,
    close_fx,
    notes_update.NoAuthCheck,
  )) =
    notes_update.try_update(
      member_notes.Model(
        ..opened,
        member_note_content: "draft",
        member_note_error: Some("old"),
      ),
      pool_messages.MemberNoteDialogClosed,
      note_context(),
    )

  let assert dialog_mode.DialogClosed = closed.member_note_dialog_mode
  let assert "" = closed.member_note_content
  let assert None = closed.member_note_error
  let assert True = close_fx == effect.none()
}

pub fn local_note_submitted_empty_sets_content_required_test() {
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes_task_id: Some(42),
      member_note_content: "   ",
    )

  let assert Some(notes_update.Update(next, fx, notes_update.NoAuthCheck)) =
    notes_update.try_update(
      model,
      pool_messages.MemberNoteSubmitted,
      note_context(),
    )

  let assert Some("Content required") = next.member_note_error
  let assert False = next.member_note_in_flight
  let assert True = fx == effect.none()
}

pub fn local_note_submitted_with_content_sets_in_flight_test() {
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes_task_id: Some(42),
      member_note_content: "  useful note  ",
      member_note_error: Some("old"),
    )

  let assert Some(notes_update.Update(next, fx, notes_update.NoAuthCheck)) =
    notes_update.try_update(
      model,
      pool_messages.MemberNoteSubmitted,
      note_context(),
    )

  let assert True = next.member_note_in_flight
  let assert None = next.member_note_error
  let assert True = fx != effect.none()
}

pub fn local_note_added_ok_prepends_note_and_closes_dialog_test() {
  let previous = Note(..sample_note(), id: note_id.new(9), content: "Previous")
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes: remote.Loaded([previous]),
      member_note_in_flight: True,
      member_note_content: "draft",
      member_note_dialog_mode: dialog_mode.DialogCreate,
    )

  let assert Some(notes_update.Update(next, fx, notes_update.NoAuthCheck)) =
    notes_update.try_update(
      model,
      pool_messages.MemberNoteAdded(Ok(sample_note())),
      note_context(),
    )

  let expected = remote.Loaded([sample_note(), previous])
  let assert True = next.member_notes == expected
  let assert False = next.member_note_in_flight
  let assert "" = next.member_note_content
  let assert dialog_mode.DialogClosed = next.member_note_dialog_mode
  let assert True = fx != effect.none()
}

pub fn local_note_added_error_sets_error_and_retries_when_task_selected_test() {
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes_task_id: Some(42),
      member_note_in_flight: True,
    )

  let assert Some(notes_update.Update(
    next,
    fx,
    notes_update.CheckAuth(policy_err),
  )) =
    notes_update.try_update(
      model,
      pool_messages.MemberNoteAdded(Error(sample_error())),
      note_context(),
    )

  let assert True = policy_err == sample_error()
  let assert False = next.member_note_in_flight
  let assert Some("boom") = next.member_note_error
  let assert True = fx != effect.none()
}

pub fn note_try_update_content_changed_without_auth_test() {
  let assert Some(notes_update.Update(next, fx, notes_update.NoAuthCheck)) =
    notes_update.try_update(
      member_notes.default_model(),
      pool_messages.MemberNoteContentChanged("draft"),
      note_context(),
    )

  let assert "draft" = next.member_note_content
  let assert True = fx == effect.none()
}

pub fn note_try_update_added_error_checks_auth_test() {
  let err = sample_error()
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes_task_id: Some(42),
      member_note_in_flight: True,
    )

  let assert Some(notes_update.Update(
    next,
    fx,
    notes_update.CheckAuth(policy_err),
  )) =
    notes_update.try_update(
      model,
      pool_messages.MemberNoteAdded(Error(err)),
      note_context(),
    )

  let assert True = policy_err == err
  let assert False = next.member_note_in_flight
  let assert Some("boom") = next.member_note_error
  let assert True = fx != effect.none()
}

pub fn note_try_update_pin_clicked_sets_in_flight_test() {
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes_task_id: Some(42),
    )

  let assert Some(notes_update.Update(next, fx, notes_update.NoAuthCheck)) =
    notes_update.try_update(
      model,
      pool_messages.MemberNotePinClicked(10, True),
      note_context(),
    )

  let assert Some(10) = next.member_note_pin_in_flight
  let assert True = fx != effect.none()
}

pub fn note_try_update_pinned_ok_replaces_note_test() {
  let previous = sample_note()
  let updated = Note(..previous, pinned: True)
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes: remote.Loaded([previous]),
      member_note_pin_in_flight: Some(note_id.to_int(previous.id)),
    )

  let assert Some(notes_update.Update(next, fx, notes_update.NoAuthCheck)) =
    notes_update.try_update(
      model,
      pool_messages.MemberNotePinned(note_id.to_int(previous.id), Ok(updated)),
      note_context(),
    )

  let assert True = next.member_notes == remote.Loaded([updated])
  let assert None = next.member_note_pin_in_flight
  let assert True = fx == effect.none()
}

pub fn note_try_update_pinned_error_checks_auth_test() {
  let err = sample_error()
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_note_pin_in_flight: Some(10),
    )

  let assert Some(notes_update.Update(
    next,
    fx,
    notes_update.CheckAuth(policy_err),
  )) =
    notes_update.try_update(
      model,
      pool_messages.MemberNotePinned(10, Error(err)),
      note_context(),
    )

  let assert True = policy_err == err
  let assert None = next.member_note_pin_in_flight
  let assert Some("boom") = next.member_note_error
  let assert True = fx == effect.none()
}

pub fn note_try_update_ignores_non_note_messages_test() {
  let assert None =
    notes_update.try_update(
      member_notes.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      note_context(),
    )
}
