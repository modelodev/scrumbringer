//// Move state helpers for the Plan structure view.

import domain/card.{type Card}
import domain/task.{type Task}
import gleam/list
import gleam/option.{type Option, None, Some}

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/cards/move_target
import scrumbringer_client/features/cards/policy as card_policy
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/plan/card_picker
import scrumbringer_client/features/plan/types

pub type DropTargetState {
  NotDropTarget
  ValidDropTarget
  InvalidDropTarget(card_policy.MoveBlockedReason)
  ActiveDropTarget
}

pub type RowState {
  MovingSource(is_dragging: Bool)
  MoveTarget(DropTargetState)
  NotMoveCandidate
}

pub fn moving_card(
  cards: List(Card),
  move_mode: member_pool.PlanMoveMode,
) -> Option(Card) {
  case move_mode {
    member_pool.PlanMovingCard(card_id, _) ->
      case list.find(cards, fn(card) { card.id == card_id }) {
        Ok(card) -> Some(card)
        Error(_) -> None
      }
    member_pool.PlanNotMoving -> None
  }
}

pub fn move_query(move_mode: member_pool.PlanMoveMode) -> String {
  case move_mode {
    member_pool.PlanMovingCard(_, query) -> query
    member_pool.PlanNotMoving -> ""
  }
}

pub fn search_state(
  cards: List(Card),
  tasks: List(Task),
  depth_names: List(scope_view.DepthName),
  move_mode: member_pool.PlanMoveMode,
) -> #(String, List(card_picker.CardOption)) {
  let query = move_query(move_mode)
  let options = case moving_card(cards, move_mode) {
    Some(card) ->
      card_policy.move_destination_entries(card, cards, tasks)
      |> card_picker.move_destination_options(cards, depth_names)
      |> card_picker.filter_options(query)
    None -> []
  }

  #(query, options)
}

pub fn destination_state(
  cards: List(Card),
  tasks: List(Task),
  move_mode: member_pool.PlanMoveMode,
  move_drag_state: member_pool.PlanMoveDragState,
  card: Card,
) -> RowState {
  case moving_card(cards, move_mode) {
    Some(source) if source.id == card.id ->
      MovingSource(is_dragging_source(move_drag_state, source.id))
    Some(source) ->
      MoveTarget(drop_target_state(cards, tasks, move_drag_state, source, card))
    None -> NotMoveCandidate
  }
}

fn is_dragging_source(
  move_drag_state: member_pool.PlanMoveDragState,
  card_id: Int,
) -> Bool {
  case move_drag_state {
    member_pool.PlanMoveDraggingCard(dragging_id, _) -> dragging_id == card_id
    member_pool.PlanMoveNotDragging -> False
  }
}

fn drop_target_state(
  cards: List(Card),
  tasks: List(Task),
  move_drag_state: member_pool.PlanMoveDragState,
  source: Card,
  destination: Card,
) -> DropTargetState {
  case card_policy.move_blocked_reason(source, destination, cards, tasks) {
    Some(reason) -> InvalidDropTarget(reason)
    None ->
      case move_drag_state {
        member_pool.PlanMoveDraggingCard(
          _,
          Some(move_target.InsideCard(over_id)),
        )
          if over_id == destination.id
        -> ActiveDropTarget
        _ -> ValidDropTarget
      }
  }
}

pub fn row_class(row_state: RowState) -> String {
  case row_state {
    MovingSource(True) -> "is-moving-source is-dragging-source"
    MovingSource(False) -> "is-moving-source"
    MoveTarget(ValidDropTarget) -> "is-move-valid"
    MoveTarget(ActiveDropTarget) -> "is-move-valid is-drop-active"
    MoveTarget(InvalidDropTarget(_)) -> "is-move-invalid"
    MoveTarget(NotDropTarget) -> ""
    NotMoveCandidate -> ""
  }
}

pub fn row_state_for_row(
  cards: List(Card),
  tasks: List(Task),
  move_mode: member_pool.PlanMoveMode,
  move_drag_state: member_pool.PlanMoveDragState,
  row: types.StructureRow,
) -> RowState {
  let types.CardRow(card:, ..) = row
  destination_state(cards, tasks, move_mode, move_drag_state, card)
}
