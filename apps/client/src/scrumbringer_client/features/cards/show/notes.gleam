//// Pure Card Show note collection helpers.

import gleam/list

import domain/note/entity.{type Note}
import domain/note/id as note_ids
import domain/remote.{type Remote, Loaded}

pub fn append(notes: Remote(List(Note)), note: Note) -> List(Note) {
  case notes {
    Loaded(existing) -> list.append(existing, [note])
    _ -> [note]
  }
}

pub fn remove(notes: Remote(List(Note)), note_id: Int) -> List(Note) {
  case notes {
    Loaded(existing) ->
      list.filter(existing, fn(note) { note_ids.to_int(note.id) != note_id })
    _ -> []
  }
}

pub fn replace(notes: Remote(List(Note)), updated_note: Note) -> List(Note) {
  case notes {
    Loaded(existing) ->
      list.map(existing, fn(note) {
        case note.id == updated_note.id {
          True -> updated_note
          False -> note
        }
      })
    _ -> [updated_note]
  }
}
