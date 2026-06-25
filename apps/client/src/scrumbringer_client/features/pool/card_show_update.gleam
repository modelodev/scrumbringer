//// Effectful card show update flow for the member pool.

import lustre/effect.{type Effect}

import gleam/option

import api/cards/contracts as card_contracts
import domain/api_error.{type ApiError, type ApiResult}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/components/card_show
import scrumbringer_client/features/admin/cards as cards_workflow
import scrumbringer_client/features/pool/card_show_state
import scrumbringer_client/features/pool/msg as pool_messages

pub type Model {
  Model(pool: member_pool.Model, cards: admin_cards.Model)
}

pub type Context(parent_msg) {
  Context(
    on_card_marked: fn(ApiResult(Nil)) -> parent_msg,
    on_card_show_msg: fn(card_show.Msg) -> parent_msg,
    on_card_activated: fn(ApiResult(card_contracts.CardActionResponse)) ->
      parent_msg,
    on_create_task: fn(Int) -> parent_msg,
    on_create_card: fn(Int) -> parent_msg,
    on_activate_card: fn(Int) -> parent_msg,
    on_move_card: fn(Int) -> parent_msg,
    on_delete_card: fn(Int) -> parent_msg,
    on_close: parent_msg,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
    hierarchy_activated: String,
    hierarchy_pool_impact: fn(Int) -> String,
    hierarchy_pool_saturated: fn(Int, Int) -> String,
    hierarchy_activate_failed: String,
  )
}

pub fn try_update(
  model: Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> option.Option(#(Model, Effect(parent_msg))) {
  case inner {
    pool_messages.OpenCardShow(card_id) ->
      option.Some(opened(model, card_id, context))
    pool_messages.CloseCardShow -> option.Some(closed(model))
    pool_messages.CardShowMsg(msg) ->
      option.Some(child_updated(model, msg, context))
    pool_messages.CardActivateRequested(card_id) ->
      option.Some(activate_requested(model, card_id, context))
    pool_messages.CardActivated(Ok(response)) ->
      option.Some(activated_ok(model, response, context))
    pool_messages.CardActivated(Error(err)) ->
      option.Some(activated_error(model, err, context))
    _ -> option.None
  }
}

fn opened(
  model: Model,
  card_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let #(show_model, show_fx) = card_show.open(card_id)
  let pool =
    card_show_state.handle_opened(model.pool, card_id)
    |> card_show_state.set_model(show_model)

  #(
    Model(
      pool: pool,
      cards: cards_workflow.handle_card_viewed(model.cards, card_id),
    ),
    effect.batch([
      api_cards.mark_card_view(card_id, context.on_card_marked),
      show_fx |> effect.map(context.on_card_show_msg),
    ]),
  )
}

fn closed(model: Model) -> #(Model, Effect(parent_msg)) {
  #(
    Model(..model, pool: card_show_state.handle_closed(model.pool)),
    effect.none(),
  )
}

fn child_updated(
  model: Model,
  msg: card_show.Msg,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  case msg {
    card_show.CreateTaskClicked -> #(
      model,
      dispatch_card_action(model.pool.card_show_open, context.on_create_task),
    )
    card_show.CreateCardClicked -> #(
      model,
      dispatch_card_action(model.pool.card_show_open, context.on_create_card),
    )
    card_show.MoveRequested -> #(
      model,
      dispatch_card_action(model.pool.card_show_open, context.on_move_card),
    )
    card_show.DeleteCardClicked -> #(
      model,
      dispatch_card_action(model.pool.card_show_open, context.on_delete_card),
    )
    card_show.CloseClicked -> #(
      model,
      effect.from(fn(dispatch) { dispatch(context.on_close) }),
    )
    card_show.ActivateCardConfirmed -> {
      let #(show_model, show_fx) =
        card_show.update(model.pool.card_show_model, msg)
      let pool = card_show_state.set_model(model.pool, show_model)
      #(
        Model(..model, pool: pool),
        effect.batch([
          show_fx |> effect.map(context.on_card_show_msg),
          dispatch_card_action(
            model.pool.card_show_open,
            context.on_activate_card,
          ),
        ]),
      )
    }
    _ -> {
      let #(show_model, show_fx) =
        card_show.update(model.pool.card_show_model, msg)
      #(
        Model(..model, pool: card_show_state.set_model(model.pool, show_model)),
        show_fx |> effect.map(context.on_card_show_msg),
      )
    }
  }
}

fn dispatch_card_action(
  card_id: option.Option(Int),
  to_msg: fn(Int) -> parent_msg,
) -> Effect(parent_msg) {
  case card_id {
    option.Some(id) -> effect.from(fn(dispatch) { dispatch(to_msg(id)) })
    option.None -> effect.none()
  }
}

fn activate_requested(
  model: Model,
  card_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  #(model, api_cards.activate_card(card_id, context.on_card_activated))
}

fn activated_ok(
  model: Model,
  response: card_contracts.CardActionResponse,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let base_message =
    context.hierarchy_activated
    <> " · "
    <> context.hierarchy_pool_impact(response.pool_impact)

  let message = case response.pool_health {
    card_contracts.PoolWithinHealthyLimit -> base_message
    card_contracts.PoolExceedsHealthyLimit ->
      base_message
      <> " · "
      <> context.hierarchy_pool_saturated(
        response.pool_open_after,
        response.healthy_pool_limit,
      )
  }

  #(model, context.on_success_toast(message))
}

fn activated_error(
  model: Model,
  err: ApiError,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  #(
    model,
    context.on_error_toast(
      context.hierarchy_activate_failed <> ": " <> err.message,
    ),
  )
}
