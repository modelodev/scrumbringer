//// Effectful card detail workflow for the member pool.

import lustre/effect.{type Effect}

import gleam/option

import domain/api_error.{type ApiError, type ApiResult}
import domain/metrics.{type CardModalMetrics}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/admin/cards as cards_workflow
import scrumbringer_client/features/pool/card_detail
import scrumbringer_client/features/pool/msg as pool_messages

pub type Model {
  Model(pool: member_pool.Model, cards: admin_cards.Model)
}

pub type Context(parent_msg) {
  Context(
    on_card_marked: fn(ApiResult(Nil)) -> parent_msg,
    on_card_metrics_fetched: fn(ApiResult(CardModalMetrics)) -> parent_msg,
  )
}

pub fn try_update(
  model: Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> option.Option(#(Model, Effect(parent_msg))) {
  case inner {
    pool_messages.OpenCardDetail(card_id) ->
      option.Some(opened(model, card_id, context))
    pool_messages.CloseCardDetail -> option.Some(closed(model))
    pool_messages.CardMetricsFetched(Ok(metrics)) ->
      option.Some(metrics_fetched_ok(model, metrics))
    pool_messages.CardMetricsFetched(Error(err)) ->
      option.Some(metrics_fetched_error(model, err))
    _ -> option.None
  }
}

pub fn opened(
  model: Model,
  card_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(
      pool: card_detail.handle_opened(model.pool, card_id),
      cards: cards_workflow.handle_card_viewed(model.cards, card_id),
    ),
    effect.batch([
      api_cards.mark_card_view(card_id, context.on_card_marked),
      api_cards.get_card_metrics(card_id, context.on_card_metrics_fetched),
    ]),
  )
}

pub fn closed(model: Model) -> #(Model, Effect(parent_msg)) {
  #(Model(..model, pool: card_detail.handle_closed(model.pool)), effect.none())
}

pub fn metrics_fetched_ok(
  model: Model,
  metrics: CardModalMetrics,
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(
      ..model,
      pool: card_detail.handle_metrics_fetched_ok(model.pool, metrics),
    ),
    effect.none(),
  )
}

pub fn metrics_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(parent_msg)) {
  #(
    Model(
      ..model,
      pool: card_detail.handle_metrics_fetched_error(model.pool, err),
    ),
    effect.none(),
  )
}
