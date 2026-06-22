//// Task notes update handlers.

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/task.{type TaskNote}
import scrumbringer_client/api/tasks/notes as task_notes_api
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/note_form
import scrumbringer_client/features/tasks/note_state

pub type Context(parent_msg) {
  Context(
    content_required: String,
    note_added: String,
    on_note_added: fn(ApiResult(TaskNote)) -> parent_msg,
    on_note_deleted: fn(Int, ApiResult(Nil)) -> parent_msg,
    on_note_pinned: fn(Int, ApiResult(TaskNote)) -> parent_msg,
    on_notes_fetched: fn(ApiResult(List(TaskNote))) -> parent_msg,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(member_notes.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: member_notes.Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberNotesFetched(Ok(notes)) ->
      handle_notes_fetched_ok(model, notes)
      |> without_auth_check

    pool_messages.MemberNotesFetched(Error(err)) ->
      handle_notes_fetched_error(model, err)
      |> with_auth_check(err)

    pool_messages.MemberNoteContentChanged(value) ->
      handle_content_changed(model, value)
      |> without_auth_check

    pool_messages.MemberNoteDialogOpened ->
      handle_dialog_opened(model)
      |> without_auth_check

    pool_messages.MemberNoteDialogClosed ->
      handle_dialog_closed(model)
      |> without_auth_check

    pool_messages.MemberNoteSubmitted ->
      handle_submitted(model, context)
      |> without_auth_check

    pool_messages.MemberNoteAdded(Ok(note)) ->
      handle_added_ok(model, note, context)
      |> without_auth_check

    pool_messages.MemberNoteAdded(Error(err)) ->
      handle_added_error(model, err, context)
      |> with_auth_check(err)

    pool_messages.MemberNoteDeleteClicked(note_id) ->
      handle_delete_clicked(model, note_id, context)
      |> without_auth_check

    pool_messages.MemberNoteDeleted(note_id, Ok(Nil)) ->
      handle_deleted_ok(model, note_id)
      |> without_auth_check

    pool_messages.MemberNoteDeleted(_note_id, Error(err)) ->
      handle_deleted_error(model, err)
      |> with_auth_check(err)

    pool_messages.MemberNotePinClicked(note_id, pinned) ->
      handle_pin_clicked(model, note_id, pinned, context)
      |> without_auth_check

    pool_messages.MemberNotePinned(_note_id, Ok(note)) ->
      handle_pinned_ok(model, note)
      |> without_auth_check

    pool_messages.MemberNotePinned(_note_id, Error(err)) ->
      handle_pinned_error(model, err)
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(member_notes.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, NoAuthCheck))
}

fn with_auth_check(
  result: #(member_notes.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, CheckAuth(err)))
}

fn handle_notes_fetched_ok(
  model: member_notes.Model,
  notes: List(TaskNote),
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.loaded(model, notes), effect.none())
}

fn handle_notes_fetched_error(
  model: member_notes.Model,
  err: ApiError,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.failed(model, err), effect.none())
}

fn handle_content_changed(
  model: member_notes.Model,
  value: String,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.content_changed(model, value), effect.none())
}

fn handle_dialog_opened(
  model: member_notes.Model,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.open_dialog(model), effect.none())
}

fn handle_dialog_closed(
  model: member_notes.Model,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.close_dialog(model), effect.none())
}

fn handle_submitted(
  model: member_notes.Model,
  context: Context(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  case model.member_note_in_flight {
    True -> #(model, effect.none())
    False -> submit_note(model, context)
  }
}

fn submit_note(
  model: member_notes.Model,
  context: Context(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  case
    note_form.evaluate(
      note_form.Input(
        task_id: model.member_notes_task_id,
        content: model.member_note_content,
      ),
      note_form.Labels(content_required: context.content_required),
    )
  {
    note_form.NoTaskSelected -> #(model, effect.none())
    note_form.Invalid(message) -> submit_note_invalid(model, message)
    note_form.Ready(task_id, content) ->
      submit_note_with_content(model, task_id, content, context)
  }
}

fn submit_note_invalid(
  model: member_notes.Model,
  message: String,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.submit_invalid(model, message), effect.none())
}

fn submit_note_with_content(
  model: member_notes.Model,
  task_id: Int,
  content: String,
  context: Context(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(
    note_state.submit_ready(model),
    task_notes_api.add_task_note(task_id, content, context.on_note_added),
  )
}

fn handle_added_ok(
  model: member_notes.Model,
  note: TaskNote,
  context: Context(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.added(model, note), context.on_success_toast(context.note_added))
}

fn handle_added_error(
  model: member_notes.Model,
  err: ApiError,
  context: Context(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  let model = note_state.add_failed(model, err)

  case model.member_notes_task_id {
    opt.Some(task_id) -> #(
      model,
      task_notes_api.list_task_notes(task_id, context.on_notes_fetched),
    )
    opt.None -> #(model, effect.none())
  }
}

fn handle_delete_clicked(
  model: member_notes.Model,
  note_id: Int,
  context: Context(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  case model.member_note_delete_in_flight, model.member_notes_task_id {
    opt.Some(_), _ -> #(model, effect.none())
    _, opt.None -> #(model, effect.none())
    opt.None, opt.Some(task_id) -> #(
      note_state.delete_started(model, note_id),
      task_notes_api.delete_task_note(task_id, note_id, fn(result) {
        context.on_note_deleted(note_id, result)
      }),
    )
  }
}

fn handle_deleted_ok(
  model: member_notes.Model,
  note_id: Int,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.deleted(model, note_id), effect.none())
}

fn handle_deleted_error(
  model: member_notes.Model,
  err: ApiError,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.delete_failed(model, err), effect.none())
}

fn handle_pin_clicked(
  model: member_notes.Model,
  note_id: Int,
  pinned: Bool,
  context: Context(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  case model.member_note_pin_in_flight, model.member_notes_task_id {
    opt.Some(_), _ -> #(model, effect.none())
    _, opt.None -> #(model, effect.none())
    opt.None, opt.Some(task_id) -> #(
      note_state.pin_started(model, note_id),
      task_notes_api.set_task_note_pinned(task_id, note_id, pinned, fn(result) {
        context.on_note_pinned(note_id, result)
      }),
    )
  }
}

fn handle_pinned_ok(
  model: member_notes.Model,
  note: TaskNote,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.pinned(model, note), effect.none())
}

fn handle_pinned_error(
  model: member_notes.Model,
  err: ApiError,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.pin_failed(model, err), effect.none())
}
