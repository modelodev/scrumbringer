//// Member pool hover note cache transitions.

import gleam/dict
import gleam/list

import domain/api_error.{type ApiResult}
import domain/note/entity.{type Note}
import scrumbringer_client/client_state/member/notes as member_notes

pub fn ensure_fetch(
  model: member_notes.Model,
  task_id: Int,
) -> #(member_notes.Model, Bool) {
  let cached = dict.get(model.member_hover_notes_cache, task_id)
  let pending = dict.get(model.member_hover_notes_pending, task_id)

  case cached, pending {
    Ok(_), _ -> #(model, False)
    _, Ok(_) -> #(model, False)
    _, _ -> #(
      member_notes.Model(
        ..model,
        member_hover_notes_pending: dict.insert(
          model.member_hover_notes_pending,
          task_id,
          True,
        ),
      ),
      True,
    )
  }
}

pub fn fetched(
  model: member_notes.Model,
  task_id: Int,
  result: ApiResult(List(Note)),
) -> member_notes.Model {
  let model =
    member_notes.Model(
      ..model,
      member_hover_notes_pending: dict.delete(
        model.member_hover_notes_pending,
        task_id,
      ),
    )

  case result {
    Ok(notes) ->
      member_notes.Model(
        ..model,
        member_hover_notes_cache: dict.insert(
          model.member_hover_notes_cache,
          task_id,
          take_last(notes, 2),
        ),
      )
    Error(_) -> model
  }
}

fn take_last(notes: List(Note), count: Int) -> List(Note) {
  let total = list.length(notes)
  case total <= count {
    True -> notes
    False -> list.drop(notes, total - count)
  }
}
