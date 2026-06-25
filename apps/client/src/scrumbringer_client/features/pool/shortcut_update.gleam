//// Keyboard shortcut update flow for the member pool.

import gleam/option as opt

import lustre/effect.{type Effect}

import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/positions as member_positions
import scrumbringer_client/features/cards/show as card_show
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/pool_prefs

pub type Model {
  Model(
    pool: member_pool.Model,
    notes: member_notes.Model,
    positions: member_positions.Model,
    card_show_open: opt.Option(Int),
    card_show_model: card_show.Model,
  )
}

pub type Context {
  Context(is_pool_shortcut_target: Bool)
}

pub type Update(parent_msg) {
  Update(Model, Effect(parent_msg))
}

pub fn try_update(
  model: Model,
  msg: pool_messages.Msg,
  context: Context,
) -> opt.Option(Update(parent_msg)) {
  case msg {
    pool_messages.GlobalKeyDown(event) -> {
      let Context(is_pool_shortcut_target: is_pool_shortcut_target) = context
      let #(model, fx) = case is_pool_shortcut_target {
        True -> handle(model, event)
        False -> #(model, effect.none())
      }
      opt.Some(Update(model, fx))
    }

    _ -> opt.None
  }
}

fn handle(
  model: Model,
  event: pool_prefs.KeyEvent,
) -> #(Model, Effect(parent_msg)) {
  case pool_prefs.shortcut_action(event) {
    pool_prefs.NoAction -> #(model, effect.none())
    pool_prefs.FocusSearch -> focus_search(model)
    pool_prefs.OpenCreate -> open_create(model)
    pool_prefs.CloseDialog -> close_dialog(model)
  }
}

fn focus_search(model: Model) -> #(Model, Effect(parent_msg)) {
  #(model, app_effects.focus_element_after_timeout("pool-filter-q", 0))
}

fn open_create(model: Model) -> #(Model, Effect(parent_msg)) {
  case model.pool.member_create_dialog_mode {
    dialog_mode.DialogCreate -> #(model, effect.none())
    _ -> #(
      Model(
        ..model,
        pool: member_pool.Model(
          ..model.pool,
          member_create_dialog_mode: dialog_mode.DialogCreate,
        ),
      ),
      effect.none(),
    )
  }
}

fn close_dialog(model: Model) -> #(Model, Effect(parent_msg)) {
  case
    model.pool.member_plan_move_drag,
    opt.is_some(model.card_show_open),
    model.pool.member_create_dialog_mode,
    opt.is_some(model.notes.member_notes_task_id),
    opt.is_some(model.positions.member_position_edit_task)
  {
    member_pool.PlanMoveDraggingCard(_, _), _, _, _, _ -> #(
      Model(
        ..model,
        pool: member_pool.Model(
          ..model.pool,
          member_plan_move_drag: member_pool.PlanMoveNotDragging,
        ),
      ),
      effect.none(),
    )
    _, True, _, _, _ -> #(
      Model(
        ..model,
        card_show_open: opt.None,
        card_show_model: card_show.reset(),
      ),
      effect.none(),
    )
    _, _, dialog_mode.DialogCreate, _, _ -> #(
      Model(
        ..model,
        pool: member_pool.Model(
          ..model.pool,
          member_create_dialog_mode: dialog_mode.DialogClosed,
        ),
      ),
      effect.none(),
    )
    _, _, _, True, _ -> #(
      Model(
        ..model,
        notes: member_notes.Model(..model.notes, member_notes_task_id: opt.None),
      ),
      effect.none(),
    )
    _, _, _, _, True -> #(
      Model(
        ..model,
        positions: member_positions.Model(
          ..model.positions,
          member_position_edit_task: opt.None,
          member_position_edit_error: opt.None,
        ),
      ),
      effect.none(),
    )
    _, _, _, _, _ -> #(model, effect.none())
  }
}
