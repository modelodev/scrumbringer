//// Member pool card detail state transitions.

import gleam/option as opt

import domain/api_error.{type ApiError}
import domain/metrics.{type CardModalMetrics}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/client_state/member/pool as member_pool

pub fn handle_opened(
  model: member_pool.Model,
  card_id: Int,
) -> member_pool.Model {
  member_pool.Model(
    ..model,
    card_detail_open: opt.Some(card_id),
    card_detail_metrics: Loading,
  )
}

pub fn handle_closed(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    card_detail_open: opt.None,
    card_detail_metrics: NotAsked,
  )
}

pub fn handle_metrics_fetched_ok(
  model: member_pool.Model,
  metrics: CardModalMetrics,
) -> member_pool.Model {
  member_pool.Model(..model, card_detail_metrics: Loaded(metrics))
}

pub fn handle_metrics_fetched_error(
  model: member_pool.Model,
  err: ApiError,
) -> member_pool.Model {
  member_pool.Model(..model, card_detail_metrics: Failed(err))
}
