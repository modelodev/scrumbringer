//// Inline Plan / Structure card movement workflow.

import gleam/int
import gleam/list
import gleam/option as opt
import lustre/effect.{type Effect}

import api/cards/contracts
import domain/api_error.{type ApiResult}
import domain/card.{type Card}
import domain/task.{type Task}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/cards/detail_policy
import scrumbringer_client/features/cards/move_target
import scrumbringer_client/features/pool/msg as pool_messages

pub type Context(parent_msg) {
  Context(
    cards: List(Card),
    tasks: List(Task),
    on_card_moved: fn(ApiResult(contracts.CardActionResponse)) -> parent_msg,
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

    pool_messages.MemberPlanMoveDestinationSelected(target) ->
      opt.Some(destination_selected(model, target, context))

    pool_messages.MemberPlanMoveDragStarted(card_id) ->
      opt.Some(#(drag_started(model, card_id), effect.none()))

    pool_messages.MemberPlanMoveDragEntered(target) ->
      opt.Some(#(drag_entered(model, target), effect.none()))

    pool_messages.MemberPlanMoveDroppedOn(target) ->
      opt.Some(destination_dropped(model, target, context))

    pool_messages.MemberPlanMoveDragEnded ->
      opt.Some(#(clear_drag(model), effect.none()))

    pool_messages.MemberPlanCardMoved(Ok(response)) ->
      opt.Some(moved_ok(model, response, context))

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
            member_plan_move_drag: member_pool.PlanMoveNotDragging,
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
            member_plan_move_drag: member_pool.PlanMoveNotDragging,
            member_plan_move_error: opt.None,
            member_plan_move_in_flight: False,
            card_show_open: opt.None,
          ),
          effect.none(),
        )
      }
    Error(_) -> #(
      member_pool.Model(
        ..model,
        member_plan_move_mode: member_pool.PlanNotMoving,
        member_plan_move_drag: member_pool.PlanMoveNotDragging,
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

fn drag_started(model: member_pool.Model, card_id: Int) -> member_pool.Model {
  case model.member_plan_move_mode, model.member_plan_move_in_flight {
    member_pool.PlanMovingCard(moving_card_id, _), False
      if moving_card_id == card_id
    ->
      member_pool.Model(
        ..model,
        member_plan_move_drag: member_pool.PlanMoveDraggingCard(
          card_id,
          opt.None,
        ),
        member_plan_move_error: opt.None,
      )
    _, _ -> model
  }
}

fn drag_entered(
  model: member_pool.Model,
  target: move_target.MoveTarget,
) -> member_pool.Model {
  case model.member_plan_move_drag {
    member_pool.PlanMoveDraggingCard(card_id, _) ->
      member_pool.Model(
        ..model,
        member_plan_move_drag: member_pool.PlanMoveDraggingCard(
          card_id,
          opt.Some(target),
        ),
      )
    member_pool.PlanMoveNotDragging -> model
  }
}

fn destination_dropped(
  model: member_pool.Model,
  target: move_target.MoveTarget,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_plan_move_drag {
    member_pool.PlanMoveDraggingCard(_, _) -> {
      let #(next, fx) = destination_selected(model, target, context)
      #(clear_drag(next), fx)
    }
    member_pool.PlanMoveNotDragging -> #(model, effect.none())
  }
}

fn destination_selected(
  model: member_pool.Model,
  target: move_target.MoveTarget,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let Context(cards:, tasks:, on_card_moved:, ..) = context
  case model.member_plan_move_mode, model.member_plan_move_in_flight {
    member_pool.PlanMovingCard(card_id, _), False -> {
      case list.find(cards, fn(card) { card.id == card_id }) {
        Ok(card) ->
          select_found_card(model, card, target, cards, tasks, on_card_moved)
        Error(_) -> #(
          member_pool.Model(
            ..model,
            member_plan_move_drag: member_pool.PlanMoveNotDragging,
            member_plan_move_error: opt.Some("No se encontro la card a mover."),
          ),
          effect.none(),
        )
      }
    }
    _, _ -> #(model, effect.none())
  }
}

fn select_found_card(
  model: member_pool.Model,
  card: Card,
  target: move_target.MoveTarget,
  cards: List(Card),
  tasks: List(Task),
  on_card_moved: fn(ApiResult(contracts.CardActionResponse)) -> parent_msg,
) -> #(member_pool.Model, Effect(parent_msg)) {
  let blocked = case target {
    move_target.ProjectRoot -> detail_policy.move_to_root_blocked_reason(card)
    move_target.InsideCard(destination_id) ->
      case list.find(cards, fn(candidate) { candidate.id == destination_id }) {
        Ok(destination) ->
          detail_policy.move_blocked_reason(card, destination, cards, tasks)
        Error(_) -> opt.Some(detail_policy.DestinationNotFound)
      }
  }

  case blocked {
    opt.None -> {
      let next =
        member_pool.Model(
          ..model,
          member_plan_move_in_flight: True,
          member_plan_move_error: opt.None,
        )
      #(
        next,
        api_cards.move_card(
          card.id,
          move_target.parent_card_id(target),
          on_card_moved,
        ),
      )
    }
    opt.Some(reason) -> #(
      member_pool.Model(
        ..model,
        member_plan_move_drag: member_pool.PlanMoveNotDragging,
        member_plan_move_error: opt.Some(
          detail_policy.move_blocked_reason_label(reason),
        ),
      ),
      effect.none(),
    )
  }
}

fn moved_ok(
  model: member_pool.Model,
  response: contracts.CardActionResponse,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let title = case
    list.find(context.cards, fn(card) { card.id == response.card_id })
  {
    Ok(card) -> card.title
    Error(_) -> "#" <> int.to_string(response.card_id)
  }
  #(
    member_pool.Model(
      ..model,
      member_plan_move_mode: member_pool.PlanNotMoving,
      member_plan_move_drag: member_pool.PlanMoveNotDragging,
      member_plan_move_in_flight: False,
      member_plan_move_error: opt.None,
    ),
    context.on_success_toast("Card movida: " <> title),
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
      member_plan_move_drag: member_pool.PlanMoveNotDragging,
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
    member_plan_move_drag: member_pool.PlanMoveNotDragging,
    member_plan_move_error: opt.None,
    member_plan_move_in_flight: False,
  )
}

pub fn clear_drag(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_plan_move_drag: member_pool.PlanMoveNotDragging,
  )
}
