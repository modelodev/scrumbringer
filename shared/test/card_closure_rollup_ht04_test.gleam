import gleam/list
import gleam/option

import domain/card/activation
import domain/card/closure
import domain/card/entity as card_entity
import domain/card/id as card_id
import domain/card/state as card_state
import domain/card/structure as card_structure
import domain/org_role
import domain/project/id as project_id
import domain/project/permissions
import domain/project/settings
import domain/project_role
import domain/task/entity as task_entity
import domain/task/id as task_id
import domain/task/placement
import domain/task/state as task_state
import domain/task/transitions
import domain/user/id as user_id

const now = "2026-06-19T10:00:00Z"

pub fn manual_card_close_blocks_when_descendant_claimed_test() {
  let card =
    active_card(1, option.None, card_structure.TaskGroup([task_id.new(1)]))
  let task =
    card_task(1, card_id.new(1), task_state.Claimed(9, now, task_state.Taken))
  let tree = activation.WorkTree(cards: [card], tasks: [task])

  let assert Error(closure.DescendantTaskClaimed(claimed_task_id)) =
    closure.close_card_manually(tree, card_id.new(1), manage_flow_actor(), now)
  let assert True = claimed_task_id == task_id.new(1)
}

pub fn manual_card_close_closes_available_descendant_tasks_test() {
  let card =
    active_card(1, option.None, card_structure.TaskGroup([task_id.new(1)]))
  let task = card_task(1, card_id.new(1), task_state.Available)
  let tree = activation.WorkTree(cards: [card], tasks: [task])

  let assert Ok(plan) =
    closure.close_card_manually(tree, card_id.new(1), manage_flow_actor(), now)
  let expected_task_state =
    task_state.Closed(task_state.ClosedByAncestor, now, 7)
  let assert option.Some(actual_task_state) =
    task_state_for(plan.updated_tree, task_id.new(1))
  let assert True = actual_task_state == expected_task_state
}

pub fn rollup_closes_parent_when_all_direct_children_closed_test() {
  let parent =
    active_card(1, option.None, card_structure.CardGroup([card_id.new(2)]))
  let child = closed_card(2, option.Some(card_id.new(1)))
  let tree = activation.WorkTree(cards: [parent, child], tasks: [])

  let assert Ok(updated_tree) =
    closure.rollup_closed_card(tree, card_id.new(1), now)
  let expected_card_state =
    card_state.Closed(card_state.Rollup, now, card_state.ClosedBySystem)
  let assert option.Some(actual_card_state) =
    card_state_for(updated_tree, card_id.new(1))
  let assert True = actual_card_state == expected_card_state
}

pub fn closed_done_counts_as_done_close_test() {
  let task = root_task(task_state.Closed(task_state.Done, now, 7))

  let assert True = closure.task_closed_with_done_reason(task)
}

pub fn closed_manually_does_not_count_as_done_close_test() {
  let task = root_task(task_state.Closed(task_state.ManuallyClosed, now, 7))

  let assert False = closure.task_closed_with_done_reason(task)
}

pub fn closed_card_outcome_all_tasks_done_when_all_leaves_done_test() {
  let card =
    closed_card_with_structure(
      1,
      option.None,
      card_structure.TaskGroup([
        task_id.new(1),
        task_id.new(2),
      ]),
    )
  let task_a =
    card_task(1, card_id.new(1), task_state.Closed(task_state.Done, now, 7))
  let task_b =
    card_task(2, card_id.new(1), task_state.Closed(task_state.Done, now, 7))
  let tree = activation.WorkTree(cards: [card], tasks: [task_a, task_b])

  let assert option.Some(closure.AllTasksClosed) =
    closure.closed_card_outcome(card, tree)
}

pub fn closed_card_outcome_without_all_tasks_done_when_any_leaf_uses_other_reason_test() {
  let card =
    closed_card_with_structure(
      1,
      option.None,
      card_structure.TaskGroup([
        task_id.new(1),
        task_id.new(2),
      ]),
    )
  let done =
    card_task(1, card_id.new(1), task_state.Closed(task_state.Done, now, 7))
  let manual =
    card_task(
      2,
      card_id.new(1),
      task_state.Closed(task_state.ManuallyClosed, now, 7),
    )
  let tree = activation.WorkTree(cards: [card], tasks: [done, manual])

  let assert option.Some(closure.ClosedWithoutAllTasksClosed) =
    closure.closed_card_outcome(card, tree)
}

pub fn manual_card_close_preserves_existing_closed_task_reasons_test() {
  let card =
    active_card(1, option.None, card_structure.TaskGroup([task_id.new(1)]))
  let task =
    card_task(1, card_id.new(1), task_state.Closed(task_state.Done, now, 9))
  let tree = activation.WorkTree(cards: [card], tasks: [task])

  let assert Ok(plan) =
    closure.close_card_manually(tree, card_id.new(1), manage_flow_actor(), now)
  let expected_task_state = task_state.Closed(task_state.Done, now, 9)
  let assert option.Some(actual_task_state) =
    task_state_for(plan.updated_tree, task_id.new(1))
  let assert True = actual_task_state == expected_task_state
}

pub fn closed_card_cannot_be_reopened_test() {
  let card = closed_card(1, option.None)
  let tree = activation.WorkTree(cards: [card], tasks: [])

  let assert Error(activation.CannotActivateClosedCard) =
    activation.activate_card(
      tree,
      card_id.new(1),
      manage_flow_actor(),
      now,
      healthy_pool_limit(20),
    )
}

pub fn closed_task_cannot_be_claimed_or_closed_again_test() {
  let task = root_task(task_state.Closed(task_state.Done, now, 7))

  let assert Error(transitions.TaskAlreadyClosed) =
    transitions.claim_task(task, user_id.new(9), now, task_state.Taken)
  let assert Error(transitions.TaskAlreadyClosed) =
    transitions.close_task(task, user_id.new(7), now)
}

fn draft_card(
  raw_id: Int,
  parent: option.Option(card_id.CardId),
  structure: card_structure.CardStructure,
) -> card_entity.Card {
  card_entity.Card(
    id: card_id.new(raw_id),
    project_id: project_id.new(1),
    parent: parent,
    structure: structure,
    execution_state: card_state.Draft,
  )
}

fn active_card(
  raw_id: Int,
  parent: option.Option(card_id.CardId),
  structure: card_structure.CardStructure,
) -> card_entity.Card {
  card_entity.Card(
    ..draft_card(raw_id, parent, structure),
    execution_state: card_state.Active(
      activated_at: now,
      activated_by: user_id.new(7),
      source: card_state.DirectActivation,
    ),
  )
}

fn closed_card(
  raw_id: Int,
  parent: option.Option(card_id.CardId),
) -> card_entity.Card {
  closed_card_with_structure(raw_id, parent, card_structure.Empty)
}

fn closed_card_with_structure(
  raw_id: Int,
  parent: option.Option(card_id.CardId),
  structure: card_structure.CardStructure,
) -> card_entity.Card {
  card_entity.Card(
    ..draft_card(raw_id, parent, structure),
    execution_state: card_state.Closed(
      reason: card_state.ManuallyClosed,
      closed_at: now,
      closed_by: card_state.ClosedByUser(user_id.new(7)),
    ),
  )
}

fn root_task(state: task_state.TaskExecutionState) -> task_entity.Task {
  task_entity.Task(
    id: task_id.new(1),
    project_id: project_id.new(1),
    placement: placement.RootPool,
    execution_state: state,
    blocked: False,
    capability_allowed: True,
  )
}

fn card_task(
  raw_id: Int,
  parent_card_id: card_id.CardId,
  state: task_state.TaskExecutionState,
) -> task_entity.Task {
  task_entity.Task(
    id: task_id.new(raw_id),
    project_id: project_id.new(1),
    placement: placement.UnderCard(parent_card_id),
    execution_state: state,
    blocked: False,
    capability_allowed: True,
  )
}

fn healthy_pool_limit(value: Int) -> settings.HealthyPoolLimit {
  let assert Ok(limit) = settings.healthy_pool_limit_from_int(value)
  limit
}

fn manage_flow_actor() -> permissions.Authorized(permissions.ManageFlow) {
  let actor =
    permissions.project_actor(
      user_id.new(7),
      project_id.new(1),
      org_role.Member,
      option.Some(project_role.Manager),
    )
  let assert Ok(auth) =
    permissions.require_manage_flow(actor, project_id.new(1))
  auth
}

fn task_state_for(
  tree: activation.WorkTree,
  id: task_id.TaskId,
) -> option.Option(task_state.TaskExecutionState) {
  let activation.WorkTree(tasks: tasks, ..) = tree
  tasks
  |> list.find(fn(task) { task.id == id })
  |> result_to_option
  |> option.map(fn(task) { task.execution_state })
}

fn card_state_for(
  tree: activation.WorkTree,
  id: card_id.CardId,
) -> option.Option(card_state.CardExecutionState) {
  let activation.WorkTree(cards: cards, ..) = tree
  cards
  |> list.find(fn(card) { card.id == id })
  |> result_to_option
  |> option.map(fn(card) { card.execution_state })
}

fn result_to_option(result: Result(a, b)) -> option.Option(a) {
  case result {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}
