//// Card activation and pool impact planning.

import domain/card/entity as card_entity
import domain/card/id as card_id
import domain/card/state
import domain/project/permissions
import domain/project/settings
import domain/task/entity as task_entity
import domain/task/placement
import domain/task/state as task_state
import gleam/int
import gleam/list
import gleam/option.{None, Some}

pub type WorkTree {
  WorkTree(cards: List(card_entity.Card), tasks: List(task_entity.Task))
}

pub type PoolHealth {
  WithinHealthyLimit
  ExceedsHealthyLimit
}

pub type PoolImpact {
  PoolImpact(
    open_before: Int,
    opened_by_action: Int,
    open_after: Int,
    healthy_pool_limit: settings.HealthyPoolLimit,
    health: PoolHealth,
  )
}

pub type CardActivationPlan {
  CardActivationPlan(
    updated_tree: WorkTree,
    pool_impact: PoolImpact,
    already_active: Bool,
  )
}

pub type ActivateCardError {
  CardNotFound
  CannotActivateClosedCard
  PermissionProjectMismatch
}

pub fn activate_card(
  tree: WorkTree,
  target_id: card_id.CardId,
  actor: permissions.Authorized(permissions.ManageFlow),
  now: String,
  healthy_pool_limit: settings.HealthyPoolLimit,
) -> Result(CardActivationPlan, ActivateCardError) {
  case find_card(tree, target_id) {
    Error(_) -> Error(CardNotFound)
    Ok(target) ->
      case
        target.execution_state,
        target.project_id == permissions.project_id(actor)
      {
        _, False -> Error(PermissionProjectMismatch)
        state.Closed(..), True -> Error(CannotActivateClosedCard)
        state.Active(..), True -> {
          let open_before = open_task_count(tree)
          let impact = pool_impact(open_before, open_before, healthy_pool_limit)
          Ok(CardActivationPlan(
            updated_tree: tree,
            pool_impact: impact,
            already_active: True,
          ))
        }
        state.Draft, True -> {
          let open_before = open_task_count(tree)
          let updated_tree = activate_scope(tree, target_id, actor, now)
          let open_after = open_task_count(updated_tree)
          Ok(CardActivationPlan(
            updated_tree: updated_tree,
            pool_impact: pool_impact(
              open_before,
              open_after,
              healthy_pool_limit,
            ),
            already_active: False,
          ))
        }
      }
  }
}

pub fn task_is_claimable_in_tree(task: task_entity.Task, tree: WorkTree) -> Bool {
  case
    task.execution_state,
    task.blocked,
    task.capability_allowed,
    task.placement
  {
    task_state.Available, False, True, placement.UnderCard(parent_id) ->
      card_allows_claim(parent_id, tree)
    _, _, _, _ -> False
  }
}

fn activate_scope(
  tree: WorkTree,
  target_id: card_id.CardId,
  actor: permissions.Authorized(permissions.ManageFlow),
  now: String,
) -> WorkTree {
  let WorkTree(cards: cards, tasks: tasks) = tree
  let updated_cards =
    cards
    |> list.map(fn(card) {
      case is_in_activation_scope(card, target_id, tree) {
        True -> activate_card_state(card, target_id, actor, now)
        False -> card
      }
    })

  WorkTree(cards: updated_cards, tasks: tasks)
}

fn activate_card_state(
  card: card_entity.Card,
  target_id: card_id.CardId,
  actor: permissions.Authorized(permissions.ManageFlow),
  now: String,
) -> card_entity.Card {
  case card.execution_state {
    state.Active(..) | state.Closed(..) -> card
    state.Draft -> {
      let source = case card.id == target_id {
        True -> state.DirectActivation
        False -> state.ActivatedByAncestor(target_id)
      }

      card_entity.Card(
        ..card,
        execution_state: state.Active(
          activated_at: now,
          activated_by: permissions.user_id(actor),
          source: source,
        ),
      )
    }
  }
}

fn pool_impact(
  open_before: Int,
  open_after: Int,
  healthy_pool_limit: settings.HealthyPoolLimit,
) -> PoolImpact {
  let limit = settings.healthy_pool_limit_to_int(healthy_pool_limit)
  let health = case open_after > limit {
    True -> ExceedsHealthyLimit
    False -> WithinHealthyLimit
  }

  PoolImpact(
    open_before: open_before,
    opened_by_action: int.max(0, open_after - open_before),
    open_after: open_after,
    healthy_pool_limit: healthy_pool_limit,
    health: health,
  )
}

fn open_task_count(tree: WorkTree) -> Int {
  let WorkTree(tasks: tasks, ..) = tree
  list.count(tasks, fn(task) { task_is_claimable_in_tree(task, tree) })
}

fn card_allows_claim(parent_id: card_id.CardId, tree: WorkTree) -> Bool {
  case find_card(tree, parent_id) {
    Error(_) -> False
    Ok(card) ->
      case card.execution_state {
        state.Active(..) -> no_closed_ancestor(card, tree)
        state.Draft | state.Closed(..) -> False
      }
  }
}

fn no_closed_ancestor(card: card_entity.Card, tree: WorkTree) -> Bool {
  case card.parent {
    None -> True
    Some(parent_id) ->
      case find_card(tree, parent_id) {
        Error(_) -> False
        Ok(parent) ->
          case parent.execution_state {
            state.Closed(..) -> False
            state.Draft | state.Active(..) -> no_closed_ancestor(parent, tree)
          }
      }
  }
}

fn is_in_activation_scope(
  card: card_entity.Card,
  target_id: card_id.CardId,
  tree: WorkTree,
) -> Bool {
  card.id == target_id || has_ancestor(card, target_id, tree)
}

fn has_ancestor(
  card: card_entity.Card,
  ancestor_id: card_id.CardId,
  tree: WorkTree,
) -> Bool {
  case card.parent {
    None -> False
    Some(parent_id) if parent_id == ancestor_id -> True
    Some(parent_id) ->
      case find_card(tree, parent_id) {
        Error(_) -> False
        Ok(parent) -> has_ancestor(parent, ancestor_id, tree)
      }
  }
}

fn find_card(
  tree: WorkTree,
  target_id: card_id.CardId,
) -> Result(card_entity.Card, Nil) {
  let WorkTree(cards: cards, ..) = tree
  list.find(cards, fn(card) { card.id == target_id })
}
