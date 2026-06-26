//// Action policy for the Plan structure view.

import domain/card.{type Card, Active, Closed, Draft}
import domain/task as domain_task
import domain/task/state as task_execution_state
import gleam/list
import gleam/option.{None, Some}

import scrumbringer_client/features/cards/policy as card_policy
import scrumbringer_client/features/plan/types
import scrumbringer_client/utils/card_queries

pub fn card_actions() -> List(types.CardAction) {
  [
    types.CreateSubcard,
    types.CreateTask,
    types.ActivateSubtree,
    types.MoveCard,
    types.CloseCard,
    types.DeleteCard,
  ]
}

pub fn action_availability(
  is_pm_or_admin: Bool,
  cards: List(Card),
  tasks: List(domain_task.Task),
  card: Card,
  action: types.CardAction,
) -> types.ActionAvailability {
  let has_subcards = card_queries.direct_child_cards(card.id, cards) != []
  let has_direct_tasks = card_queries.direct_child_tasks(card.id, tasks) != []
  case action {
    types.CreateSubcard ->
      case is_pm_or_admin, has_direct_tasks {
        False, _ -> types.Disabled("Solo managers pueden modificar estructura")
        _, True -> types.Disabled("Esta tarjeta ya contiene tareas directas")
        _, False -> types.Available
      }
    types.CreateTask ->
      case has_subcards {
        True -> types.Disabled("Esta tarjeta contiene subtarjetas")
        False -> types.Available
      }
    types.ActivateSubtree ->
      case is_pm_or_admin, card.state {
        False, _ -> types.Disabled("Solo managers pueden activar subárboles")
        _, Draft -> types.Available
        _, Active -> types.Disabled("Ya activo")
        _, Closed -> types.Disabled("La tarjeta está cerrada")
      }
    types.MoveCard ->
      case
        is_pm_or_admin,
        card_policy.move_unavailable_reason(card, cards, tasks)
      {
        True, None -> types.Available
        True, Some(reason) ->
          types.Disabled(card_policy.move_blocked_reason_label(reason))
        False, _ -> types.Disabled("Solo managers pueden mover tarjetas")
      }
    types.CloseCard ->
      case
        is_pm_or_admin,
        has_claimed_or_ongoing_descendants(cards, tasks, card)
      {
        False, _ -> types.Disabled("Solo managers pueden cerrar tarjetas")
        _, True -> types.Disabled("Hay tareas reclamadas o en curso debajo")
        _, False -> types.Available
      }
    types.DeleteCard ->
      case has_subcards || has_direct_tasks || card.task_count > 0 {
        True ->
          types.Disabled("Tiene historial operativo; cierrala en su lugar")
        False -> types.Available
      }
  }
}

fn has_claimed_or_ongoing_descendants(
  cards: List(Card),
  tasks: List(domain_task.Task),
  card: Card,
) -> Bool {
  tasks
  |> list.filter(fn(task) {
    card_queries.task_in_card_subtree(task, card.id, cards)
  })
  |> list.any(fn(task) {
    case task.state {
      task_execution_state.Claimed(..) -> True
      _ -> False
    }
  })
}

pub fn action_testid(action: types.CardAction) -> String {
  case action {
    types.CreateSubcard -> "plan-action-create-subcard"
    types.CreateTask -> "plan-action-create-task"
    types.ActivateSubtree -> "plan-action-activate-subtree"
    types.MoveCard -> "plan-action-move-card"
    types.CloseCard -> "plan-action-close-card"
    types.DeleteCard -> "plan-action-delete-card"
  }
}
