//// Pure task note state transitions.

import gleam/list
import gleam/option as opt

import domain/api_error.{type ApiError}
import domain/note/entity.{type Note}
import domain/note/id as note_ids
import domain/remote.{Failed, Loaded}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/notes as member_notes

pub fn loaded(
  notes_model: member_notes.Model,
  notes: List(Note),
) -> member_notes.Model {
  member_notes.Model(..notes_model, member_notes: Loaded(notes))
}

pub fn failed(
  notes_model: member_notes.Model,
  err: ApiError,
) -> member_notes.Model {
  member_notes.Model(..notes_model, member_notes: Failed(err))
}

pub fn content_changed(
  notes_model: member_notes.Model,
  value: String,
) -> member_notes.Model {
  member_notes.Model(..notes_model, member_note_content: value)
}

pub fn open_dialog(notes_model: member_notes.Model) -> member_notes.Model {
  member_notes.Model(
    ..notes_model,
    member_note_dialog_mode: dialog_mode.DialogCreate,
    member_note_error: opt.None,
  )
}

pub fn close_dialog(notes_model: member_notes.Model) -> member_notes.Model {
  member_notes.Model(
    ..notes_model,
    member_note_dialog_mode: dialog_mode.DialogClosed,
    member_note_content: "",
    member_note_error: opt.None,
  )
}

pub fn submit_invalid(
  notes_model: member_notes.Model,
  message: String,
) -> member_notes.Model {
  member_notes.Model(..notes_model, member_note_error: opt.Some(message))
}

pub fn submit_ready(notes_model: member_notes.Model) -> member_notes.Model {
  member_notes.Model(
    ..notes_model,
    member_note_in_flight: True,
    member_note_error: opt.None,
  )
}

pub fn added(notes_model: member_notes.Model, note: Note) -> member_notes.Model {
  let updated = case notes_model.member_notes {
    Loaded(notes) -> [note, ..notes]
    _ -> [note]
  }

  member_notes.Model(
    ..notes_model,
    member_note_in_flight: False,
    member_note_content: "",
    member_note_dialog_mode: dialog_mode.DialogClosed,
    member_notes: Loaded(updated),
  )
}

pub fn add_failed(
  notes_model: member_notes.Model,
  err: ApiError,
) -> member_notes.Model {
  member_notes.Model(
    ..notes_model,
    member_note_in_flight: False,
    member_note_error: opt.Some(err.message),
  )
}

pub fn delete_started(
  notes_model: member_notes.Model,
  note_id: Int,
) -> member_notes.Model {
  member_notes.Model(
    ..notes_model,
    member_note_delete_in_flight: opt.Some(note_id),
    member_note_error: opt.None,
  )
}

pub fn deleted(
  notes_model: member_notes.Model,
  note_id: Int,
) -> member_notes.Model {
  let notes = case notes_model.member_notes {
    Loaded(items) ->
      items
      |> list.filter(fn(note) { note_ids.to_int(note.id) != note_id })
      |> Loaded
    other -> other
  }

  member_notes.Model(
    ..notes_model,
    member_notes: notes,
    member_note_delete_in_flight: opt.None,
  )
}

pub fn delete_failed(
  notes_model: member_notes.Model,
  err: ApiError,
) -> member_notes.Model {
  member_notes.Model(
    ..notes_model,
    member_note_delete_in_flight: opt.None,
    member_note_error: opt.Some(err.message),
  )
}

pub fn pin_started(
  notes_model: member_notes.Model,
  note_id: Int,
) -> member_notes.Model {
  member_notes.Model(
    ..notes_model,
    member_note_pin_in_flight: opt.Some(note_id),
    member_note_error: opt.None,
  )
}

pub fn pinned(
  notes_model: member_notes.Model,
  updated_note: Note,
) -> member_notes.Model {
  let notes = case notes_model.member_notes {
    Loaded(items) ->
      items
      |> list.map(fn(note) {
        case note_ids.to_int(note.id) == note_ids.to_int(updated_note.id) {
          True -> updated_note
          False -> note
        }
      })
      |> Loaded
    other -> other
  }

  member_notes.Model(
    ..notes_model,
    member_notes: notes,
    member_note_pin_in_flight: opt.None,
  )
}

pub fn pin_failed(
  notes_model: member_notes.Model,
  err: ApiError,
) -> member_notes.Model {
  member_notes.Model(
    ..notes_model,
    member_note_pin_in_flight: opt.None,
    member_note_error: opt.Some(err.message),
  )
}
