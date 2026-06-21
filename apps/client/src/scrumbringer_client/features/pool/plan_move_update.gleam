//// Inline Plan / Structure card movement workflow.

import gleam/list
import gleam/option as opt
import lustre/effect.{type Effect}

import domain/api_error.{type ApiResult}
import domain/card.{type Card}
import domain/task.{type Task}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/cards/detail_policy
import scrumbringer_client/features/pool/msg as pool_messages

pub type Context(parent_msg) {
  Context(
    cards: List(Card),
    tasks: List(Task),
    on_card_moved: fn(ApiResult(Card)) -> parent_msg,
    on_success_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(#(member_pool.Model, Effect(parent_msg))) {
  case inner {
    pool_messages.MemberPlanMoveRequested(card_id) ->
      opt.Some(move_requested(model, card_id, context))

    pool_messages.MemberPlanMoveCancelled ->
      opt.Some(#(cancel(model), effect.none()))

    pool_messages.MemberPlanMoveDestinationSearchChanged(query) ->
      opt.Some(#(destination_search_changed(model, query), effect.none()))

    pool_messages.MemberPlanMoveDestinationSelected(destination_id) ->
      opt.Some(destination_selected(model, destination_id, context))

    pool_messages.MemberPlanCardMoved(Ok(card)) ->
      opt.Some(moved_ok(model, card, context))

    pool_messages.MemberPlanCardMoved(Error(err)) ->
      opt.Some(moved_error(model, err.message, context))

    _ -> opt.None
  }
}

fn move_requested(
  model: member_pool.Model,
  card_id: Int,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let Context(cards:, tasks:, ..) = context
  case list.find(cards, fn(card) { card.id == card_id }) {
    Ok(card) ->
      case detail_policy.move_unavailable_reason(card, cards, tasks) {
        opt.Some(reason) -> #(
          member_pool.Model(
            ..model,
            member_plan_move_mode: member_pool.PlanNotMoving,
            member_plan_move_error: opt.Some(
              detail_policy.move_blocked_reason_label(reason),
            ),
            member_plan_move_in_flight: False,
          ),
          effect.none(),
        )
        opt.None -> #(
          member_pool.Model(
            ..model,
            member_plan_move_mode: member_pool.PlanMovingCard(card_id, ""),
            member_plan_move_error: opt.None,
            member_plan_move_in_flight: False,
            card_detail_open: opt.None,
          ),
          effect.none(),
        )
      }
    Error(_) -> #(
      member_pool.Model(
        ..model,
        member_plan_move_mode: member_pool.PlanNotMoving,
        member_plan_move_error: opt.Some("No se encontro la card a mover."),
        member_plan_move_in_flight: False,
      ),
      effect.none(),
    )
  }
}

fn destination_search_changed(
  model: member_pool.Model,
  query: String,
) -> member_pool.Model {
  case model.member_plan_move_mode {
    member_pool.PlanMovingCard(card_id, _) ->
      member_pool.Model(
        ..model,
        member_plan_move_mode: member_pool.PlanMovingCard(card_id, query),
      )
    member_pool.PlanNotMoving -> model
  }
}

fn destination_selected(
  model: member_pool.Model,
  destination_id: Int,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let Context(cards:, tasks:, on_card_moved:, ..) = context
  case model.member_plan_move_mode, model.member_plan_move_in_flight {
    member_pool.PlanMovingCard(card_id, _), False -> {
      case
        list.find(cards, fn(card) { card.id == card_id }),
        list.find(cards, fn(card) { card.id == destination_id })
      {
        Ok(card), Ok(destination) ->
          case
            detail_policy.move_blocked_reason(card, destination, cards, tasks)
          {
            opt.None -> {
              let next =
                member_pool.Model(
                  ..model,
                  member_plan_move_in_flight: True,
                  member_plan_move_error: opt.None,
                )
              #(
                next,
                api_cards.update_card(
                  card.id,
                  card.title,
                  card.description,
                  card.color,
                  opt.Some(destination.id),
                  on_card_moved,
                ),
              )
            }
            opt.Some(reason) -> #(
              member_pool.Model(
                ..model,
                member_plan_move_error: opt.Some(
                  detail_policy.move_blocked_reason_label(reason),
                ),
              ),
              effect.none(),
            )
          }
        _, _ -> #(
          member_pool.Model(
            ..model,
            member_plan_move_error: opt.Some(
              "No se encontro el destino seleccionado.",
            ),
          ),
          effect.none(),
        )
      }
    }
    _, _ -> #(model, effect.none())
  }
}

fn moved_ok(
  model: member_pool.Model,
  card: Card,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    member_pool.Model(
      ..model,
      member_plan_move_mode: member_pool.PlanNotMoving,
      member_plan_move_in_flight: False,
      member_plan_move_error: opt.None,
    ),
    context.on_success_toast("Card movida: " <> card.title),
  )
}

fn moved_error(
  model: member_pool.Model,
  message: String,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let feedback = "No se pudo mover la card: " <> message
  #(
    member_pool.Model(
      ..model,
      member_plan_move_in_flight: False,
      member_plan_move_error: opt.Some(feedback),
    ),
    context.on_error_toast(feedback),
  )
}

fn cancel(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_plan_move_mode: member_pool.PlanNotMoving,
    member_plan_move_error: opt.None,
    member_plan_move_in_flight: False,
  )
}
