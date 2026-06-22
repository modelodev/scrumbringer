import gleam/dict
import gleam/int
import gleam/option.{None}

import domain/api_error.{type ApiError, ApiError}
import domain/task.{type TaskNote, TaskNote}
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/features/pool/hover_notes

fn sample_note(id: Int) -> TaskNote {
  TaskNote(
    id: id,
    task_id: 42,
    user_id: 7,
    content: "Note " <> int.to_string(id),
    url: None,
    pinned: False,
    created_at: "2026-06-02T12:00:00Z",
    updated_at: "2026-06-02T12:00:00Z",
  )
}

fn sample_error() -> ApiError {
  ApiError(status: 500, code: "ERR", message: "boom")
}

pub fn ensure_fetch_marks_pending_once_test() {
  let #(next, should_fetch) =
    hover_notes.ensure_fetch(member_notes.default_model(), 42)

  let assert True = should_fetch
  let assert Ok(True) = dict.get(next.member_hover_notes_pending, 42)

  let #(again, should_fetch_again) = hover_notes.ensure_fetch(next, 42)
  let assert False = should_fetch_again
  let assert Ok(True) = dict.get(again.member_hover_notes_pending, 42)
}

pub fn fetched_success_caches_last_two_notes_and_clears_pending_test() {
  let #(pending, _) = hover_notes.ensure_fetch(member_notes.default_model(), 42)
  let next =
    hover_notes.fetched(
      pending,
      42,
      Ok([sample_note(1), sample_note(2), sample_note(3)]),
    )

  let assert Error(_) = dict.get(next.member_hover_notes_pending, 42)
  let assert Ok([TaskNote(id: 2, ..), TaskNote(id: 3, ..)]) =
    dict.get(next.member_hover_notes_cache, 42)
}

pub fn fetched_error_only_clears_pending_test() {
  let #(pending, _) = hover_notes.ensure_fetch(member_notes.default_model(), 42)
  let next = hover_notes.fetched(pending, 42, Error(sample_error()))

  let assert Error(_) = dict.get(next.member_hover_notes_pending, 42)
  let assert Error(_) = dict.get(next.member_hover_notes_cache, 42)
}
