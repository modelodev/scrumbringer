//// Card closure, rollup, and completion outcome rules.

import domain/card/activation.{type WorkTree}
import domain/card/entity as card_entity
import domain/card/id as card_id
import domain/card/state as card_state
import domain/card/structure as card_structure
import domain/project/permissions
import domain/task/entity as task_entity
import domain/task/id as task_id
import domain/task/placement
import domain/task/state as task_state
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type ManualCardClosePlan {
  ManualCardClosePlan(updated_tree: WorkTree)
}

pub type ManualCardCloseError {
  CardNotFound
  PermissionProjectMismatch
  CardAlreadyClosed
  DescendantTaskClaimed(task_id.TaskId)
}

pub type RollupError {
  RollupCardNotFound
  RollupCardAlreadyClosed
  RollupChildrenStillOpen
}

pub type ClosedCardOutcome {
  Done
  ClosedWithoutCompletion
}

pub fn close_card_manually(
  tree: WorkTree,
  target_id: card_id.CardId,
  actor: permissions.Authorized(permissions.ManageFlow),
  now: String,
) -> Result(ManualCardClosePlan, ManualCardCloseError) {
  use target <- result.try(find_card_for_manual_close(tree, target_id))

  case target.project_id == permissions.project_id(actor) {
    False -> Error(PermissionProjectMismatch)
    True -> close_authorized_card(tree, target, actor, now)
  }
}

pub fn rollup_closed_card(
  tree: WorkTree,
  target_id: card_id.CardId,
  now: String,
) -> Result(WorkTree, RollupError) {
  use target <- result.try(find_card_for_rollup(tree, target_id))

  case direct_children_closed(target, tree) {
    False -> Error(RollupChildrenStillOpen)
    True -> {
      let activation.WorkTree(cards: cards, tasks: tasks) = tree
      let updated_cards =
        cards
        |> list.map(fn(card) {
          case card.id == target_id {
            True ->
              card_entity.Card(
                ..card,
                execution_state: card_state.Closed(
                  reason: card_state.Rollup,
                  closed_at: now,
                  closed_by: card_state.ClosedBySystem,
                ),
              )
            False -> card
          }
        })

      Ok(activation.WorkTree(cards: updated_cards, tasks: tasks))
    }
  }
}

pub fn task_counts_as_completed(task: task_entity.Task) -> Bool {
  case task.execution_state {
    task_state.Closed(task_state.Done, _, _) -> True
    _ -> False
  }
}

pub fn closed_card_outcome(
  card: card_entity.Card,
  tree: WorkTree,
) -> Option(ClosedCardOutcome) {
  case card.execution_state {
    card_state.Closed(..) -> {
      let leaves = descendant_tasks(card.id, tree)
      case leaves {
        [] -> Some(ClosedWithoutCompletion)
        _ ->
          case list.all(leaves, task_counts_as_completed) {
            True -> Some(Done)
            False -> Some(ClosedWithoutCompletion)
          }
      }
    }
    _ -> None
  }
}

fn close_authorized_card(
  tree: WorkTree,
  target: card_entity.Card,
  actor: permissions.Authorized(permissions.ManageFlow),
  now: String,
) -> Result(ManualCardClosePlan, ManualCardCloseError) {
  case first_claimed_descendant_task(target.id, tree) {
    Some(task_id) -> Error(DescendantTaskClaimed(task_id))
    None -> {
      let activation.WorkTree(cards: cards, tasks: tasks) = tree
      let updated_cards =
        cards
        |> list.map(fn(card) {
          case card_in_scope(card, target.id, tree) {
            True -> close_card_if_open(card, actor, now)
            False -> card
          }
        })
      let updated_tasks =
        tasks
        |> list.map(fn(task) {
          case task_in_scope(task, target.id, tree) {
            True -> close_task_if_available(task, actor, now)
            False -> task
          }
        })

      Ok(
        ManualCardClosePlan(updated_tree: activation.WorkTree(
          cards: updated_cards,
          tasks: updated_tasks,
        )),
      )
    }
  }
}

fn close_card_if_open(
  card: card_entity.Card,
  actor: permissions.Authorized(permissions.ManageFlow),
  now: String,
) -> card_entity.Card {
  case card.execution_state {
    card_state.Closed(..) -> card
    card_state.Draft | card_state.Active(..) ->
      card_entity.Card(
        ..card,
        execution_state: card_state.Closed(
          reason: card_state.ManuallyClosed,
          closed_at: now,
          closed_by: card_state.ClosedByUser(permissions.user_id(actor)),
        ),
      )
  }
}

fn close_task_if_available(
  task: task_entity.Task,
  actor: permissions.Authorized(permissions.ManageFlow),
  now: String,
) -> task_entity.Task {
  case task.execution_state {
    task_state.Available ->
      task_entity.Task(
        ..task,
        execution_state: task_state.Closed(
          reason: task_state.ClosedByAncestor,
          closed_at: now,
          closed_by: permissions.user_id(actor),
        ),
      )
    task_state.Claimed(..) | task_state.Closed(..) -> task
  }
}

fn find_card_for_manual_close(
  tree: WorkTree,
  target_id: card_id.CardId,
) -> Result(card_entity.Card, ManualCardCloseError) {
  case find_card(tree, target_id) {
    Error(_) -> Error(CardNotFound)
    Ok(card) ->
      case card.execution_state {
        card_state.Closed(..) -> Error(CardAlreadyClosed)
        _ -> Ok(card)
      }
  }
}

fn find_card_for_rollup(
  tree: WorkTree,
  target_id: card_id.CardId,
) -> Result(card_entity.Card, RollupError) {
  case find_card(tree, target_id) {
    Error(_) -> Error(RollupCardNotFound)
    Ok(card) ->
      case card.execution_state {
        card_state.Closed(..) -> Error(RollupCardAlreadyClosed)
        _ -> Ok(card)
      }
  }
}

fn direct_children_closed(card: card_entity.Card, tree: WorkTree) -> Bool {
  case card.structure {
    card_structure.Empty -> False
    card_structure.TaskGroup(task_ids) ->
      list.all(task_ids, fn(id) { task_id_closed(id, tree) })
    card_structure.CardGroup(card_ids) ->
      list.all(card_ids, fn(id) { card_id_closed(id, tree) })
  }
}

fn task_id_closed(id: task_id.TaskId, tree: WorkTree) -> Bool {
  case find_task(tree, id) {
    Error(_) -> False
    Ok(task) ->
      case task.execution_state {
        task_state.Closed(..) -> True
        _ -> False
      }
  }
}

fn card_id_closed(id: card_id.CardId, tree: WorkTree) -> Bool {
  case find_card(tree, id) {
    Error(_) -> False
    Ok(card) ->
      case card.execution_state {
        card_state.Closed(..) -> True
        _ -> False
      }
  }
}

fn first_claimed_descendant_task(
  target_id: card_id.CardId,
  tree: WorkTree,
) -> Option(task_id.TaskId) {
  let activation.WorkTree(tasks: tasks, ..) = tree
  case
    list.find(tasks, fn(task) {
      task_in_scope(task, target_id, tree) && task_is_claimed(task)
    })
  {
    Ok(task) -> Some(task.id)
    Error(_) -> None
  }
}

fn task_is_claimed(task: task_entity.Task) -> Bool {
  case task.execution_state {
    task_state.Claimed(..) -> True
    _ -> False
  }
}

fn descendant_tasks(
  target_id: card_id.CardId,
  tree: WorkTree,
) -> List(task_entity.Task) {
  let activation.WorkTree(tasks: tasks, ..) = tree
  tasks
  |> list.filter(fn(task) { task_in_scope(task, target_id, tree) })
}

fn task_in_scope(
  task: task_entity.Task,
  target_id: card_id.CardId,
  tree: WorkTree,
) -> Bool {
  case task.placement {
    placement.RootPool -> False
    placement.UnderCard(parent_id) -> {
      case find_card(tree, parent_id) {
        Error(_) -> False
        Ok(parent) -> card_in_scope(parent, target_id, tree)
      }
    }
  }
}

fn card_in_scope(
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
  let activation.WorkTree(cards: cards, ..) = tree
  list.find(cards, fn(card) { card.id == target_id })
}

fn find_task(
  tree: WorkTree,
  target_id: task_id.TaskId,
) -> Result(task_entity.Task, Nil) {
  let activation.WorkTree(tasks: tasks, ..) = tree
  list.find(tasks, fn(task) { task.id == target_id })
}
