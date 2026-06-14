import gleam/option.{None, Some}
import lustre/effect

import domain/api_error.{type ApiError, ApiError}
import domain/remote
import domain/task.{type TaskNote, TaskNote}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/update as tasks_update

fn note_context() -> tasks_update.NoteContext(Nil) {
  tasks_update.NoteContext(
    content_required: "Content required",
    note_added: "Note added",
    on_note_added: fn(_result) { Nil },
    on_note_deleted: fn(_note_id, _result) { Nil },
    on_notes_fetched: fn(_result) { Nil },
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn sample_note() -> TaskNote {
  TaskNote(
    id: 10,
    task_id: 42,
    user_id: 7,
    content: "Reviewed",
    created_at: "2026-03-20T14:00:00Z",
  )
}

fn sample_error() -> ApiError {
  ApiError(status: 500, code: "ERR", message: "boom")
}

pub fn local_note_content_changed_updates_content_test() {
  let #(next, fx) =
    tasks_update.handle_note_content_changed(
      member_notes.default_model(),
      "draft",
    )

  let assert "draft" = next.member_note_content
  let assert True = fx == effect.none()
}

pub fn local_note_dialog_opened_and_closed_updates_dialog_state_test() {
  let #(opened, open_fx) =
    tasks_update.handle_note_dialog_opened(
      member_notes.Model(
        ..member_notes.default_model(),
        member_note_error: Some("old"),
      ),
    )

  let assert dialog_mode.DialogCreate = opened.member_note_dialog_mode
  let assert None = opened.member_note_error
  let assert True = open_fx == effect.none()

  let #(closed, close_fx) =
    tasks_update.handle_note_dialog_closed(
      member_notes.Model(
        ..opened,
        member_note_content: "draft",
        member_note_error: Some("old"),
      ),
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

  let #(next, fx) = tasks_update.handle_note_submitted(model, note_context())

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

  let #(next, fx) = tasks_update.handle_note_submitted(model, note_context())

  let assert True = next.member_note_in_flight
  let assert None = next.member_note_error
  let assert True = fx != effect.none()
}

pub fn local_note_added_ok_prepends_note_and_closes_dialog_test() {
  let previous = TaskNote(..sample_note(), id: 9, content: "Previous")
  let model =
    member_notes.Model(
      ..member_notes.default_model(),
      member_notes: remote.Loaded([previous]),
      member_note_in_flight: True,
      member_note_content: "draft",
      member_note_dialog_mode: dialog_mode.DialogCreate,
    )

  let #(next, fx) =
    tasks_update.handle_note_added_ok(model, sample_note(), note_context())

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

  let #(next, fx) =
    tasks_update.handle_note_added_error(model, sample_error(), note_context())

  let assert False = next.member_note_in_flight
  let assert Some("boom") = next.member_note_error
  let assert True = fx != effect.none()
}

pub fn note_try_update_content_changed_without_auth_test() {
  let assert Some(tasks_update.NoteUpdate(next, fx, tasks_update.NoAuthCheck)) =
    tasks_update.try_note_update(
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

  let assert Some(tasks_update.NoteUpdate(
    next,
    fx,
    tasks_update.CheckAuth(policy_err),
  )) =
    tasks_update.try_note_update(
      model,
      pool_messages.MemberNoteAdded(Error(err)),
      note_context(),
    )

  let assert True = policy_err == err
  let assert False = next.member_note_in_flight
  let assert Some("boom") = next.member_note_error
  let assert True = fx != effect.none()
}

pub fn note_try_update_ignores_non_note_messages_test() {
  let assert None =
    tasks_update.try_note_update(
      member_notes.default_model(),
      pool_messages.MemberPoolFiltersToggled,
      note_context(),
    )
}
