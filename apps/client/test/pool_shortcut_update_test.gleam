import gleam/option.{None, Some}

import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/shortcut_update
import scrumbringer_client/pool_prefs

fn local_model() -> shortcut_update.Model {
  shortcut_update.Model(
    pool: member_pool.default_model(),
    notes: member_notes.default_model(),
    positions: member_positions.default_model(),
  )
}

fn key(key: String) -> pool_prefs.KeyEvent {
  pool_prefs.KeyEvent(
    key: key,
    ctrl: False,
    meta: False,
    shift: False,
    is_editing: False,
    modal_open: False,
  )
}

fn shortcut(
  model: shortcut_update.Model,
  key_name: String,
) -> shortcut_update.Model {
  let assert Some(shortcut_update.Update(next, _fx)) =
    shortcut_update.try_update(
      model,
      pool_messages.GlobalKeyDown(key(key_name)),
      shortcut_update.Context(is_pool_shortcut_target: True),
    )
  next
}

pub fn shortcut_update_f_key_has_no_pool_action_test() {
  let next = shortcut(local_model(), "f")

  let assert True = next == local_model()
}

pub fn shortcut_try_update_global_keydown_consumes_focus_search_test() {
  let assert Some(shortcut_update.Update(next, _fx)) =
    shortcut_update.try_update(
      local_model(),
      pool_messages.GlobalKeyDown(key("/")),
      shortcut_update.Context(is_pool_shortcut_target: True),
    )

  let assert True = next == local_model()
}

pub fn shortcut_try_update_global_keydown_consumes_inactive_target_test() {
  let initial = local_model()
  let assert Some(shortcut_update.Update(next, _fx)) =
    shortcut_update.try_update(
      initial,
      pool_messages.GlobalKeyDown(key("f")),
      shortcut_update.Context(is_pool_shortcut_target: False),
    )

  let assert True = next == initial
}

pub fn shortcut_try_update_ignores_non_shortcut_message_test() {
  let assert None =
    shortcut_update.try_update(
      local_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      shortcut_update.Context(is_pool_shortcut_target: True),
    )
}

pub fn shortcut_update_open_and_close_create_dialog_test() {
  let opened = shortcut(local_model(), "n")
  let assert dialog_mode.DialogCreate = opened.pool.member_create_dialog_mode

  let closed = shortcut(opened, "Escape")
  let assert dialog_mode.DialogClosed = closed.pool.member_create_dialog_mode
}

pub fn shortcut_update_escape_closes_notes_detail_test() {
  let model =
    shortcut_update.Model(
      ..local_model(),
      notes: member_notes.Model(
        ..member_notes.default_model(),
        member_notes_task_id: Some(42),
      ),
    )

  let next = shortcut(model, "Escape")

  let assert None = next.notes.member_notes_task_id
}

pub fn shortcut_update_escape_closes_position_edit_test() {
  let model =
    shortcut_update.Model(
      ..local_model(),
      positions: member_positions.Model(
        ..member_positions.default_model(),
        member_position_edit_task: Some(7),
        member_position_edit_error: Some("boom"),
      ),
    )

  let next = shortcut(model, "Escape")

  let assert None = next.positions.member_position_edit_task
  let assert None = next.positions.member_position_edit_error
}
