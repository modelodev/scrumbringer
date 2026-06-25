import gleam/list
import gleam/option

import domain/card/activation
import domain/card/entity as card_entity
import domain/card/id as card_id
import domain/card/state as card_state
import domain/card/structure as card_structure
import domain/project/id as project_id
import domain/project/permissions
import domain/project/settings
import domain/task/claimability
import domain/task/entity as task_entity
import domain/task/id as task_id
import domain/task/placement
import domain/task/state as task_state
import domain/user/id as user_id

const now = "2026-06-19T10:00:00Z"

pub fn card_is_never_claimable_test() {
  let card = draft_card(1, option.None, card_structure.Empty)

  let assert False = claimability.card_is_claimable(card)
}

pub fn root_pool_task_is_claimable_without_card_activation_test() {
  let task = root_task(1, task_state.Available)
  let tree = activation.WorkTree(cards: [], tasks: [task])

  let assert True = claimability.task_is_claimable(task, tree)
}

pub fn task_under_draft_card_is_not_claimable_test() {
  let card =
    draft_card(1, option.None, card_structure.TaskGroup([task_id.new(1)]))
  let task = card_task(1, card_id.new(1), task_state.Available)
  let tree = activation.WorkTree(cards: [card], tasks: [task])

  let assert False = claimability.task_is_claimable(task, tree)
}

pub fn task_under_active_card_is_claimable_test() {
  let card =
    active_card(1, option.None, card_structure.TaskGroup([task_id.new(1)]))
  let task = card_task(1, card_id.new(1), task_state.Available)
  let tree = activation.WorkTree(cards: [card], tasks: [task])

  let assert True = claimability.task_is_claimable(task, tree)
}

pub fn activation_counts_descendant_available_tasks_test() {
  let root =
    draft_card(1, option.None, card_structure.CardGroup([card_id.new(2)]))
  let child =
    draft_card(
      2,
      option.Some(card_id.new(1)),
      card_structure.TaskGroup([task_id.new(1), task_id.new(2)]),
    )
  let task_a = card_task(1, card_id.new(2), task_state.Available)
  let task_b = card_task(2, card_id.new(2), task_state.Available)
  let tree = activation.WorkTree(cards: [root, child], tasks: [task_a, task_b])

  let assert Ok(plan) =
    activation.activate_card(
      tree,
      card_id.new(1),
      manage_flow_actor(),
      now,
      healthy_pool_limit(20),
    )

  let assert 2 = plan.pool_impact.opened_by_action
}

pub fn activation_propagates_down_not_up_test() {
  let root =
    draft_card(1, option.None, card_structure.CardGroup([card_id.new(2)]))
  let child =
    draft_card(
      2,
      option.Some(card_id.new(1)),
      card_structure.TaskGroup([task_id.new(1)]),
    )
  let task = card_task(1, card_id.new(2), task_state.Available)
  let tree = activation.WorkTree(cards: [root, child], tasks: [task])

  let assert Ok(plan) =
    activation.activate_card(
      tree,
      card_id.new(2),
      manage_flow_actor(),
      now,
      healthy_pool_limit(20),
    )

  let assert option.Some(card_state.Draft) =
    card_state_for(plan.updated_tree, card_id.new(1))
  let expected_child_state =
    card_state.Active(
      activated_at: now,
      activated_by: user_id.new(7),
      source: card_state.DirectActivation,
    )
  let assert option.Some(actual_child_state) =
    card_state_for(plan.updated_tree, card_id.new(2))
  let assert True = actual_child_state == expected_child_state
}

pub fn activating_empty_card_reports_zero_pool_impact_test() {
  let card = draft_card(1, option.None, card_structure.Empty)
  let tree = activation.WorkTree(cards: [card], tasks: [])

  let assert Ok(plan) =
    activation.activate_card(
      tree,
      card_id.new(1),
      manage_flow_actor(),
      now,
      healthy_pool_limit(20),
    )

  let assert 0 = plan.pool_impact.opened_by_action
  let assert 0 = plan.pool_impact.open_after
}

pub fn activating_already_active_card_is_idempotent_test() {
  let card =
    active_card(1, option.None, card_structure.TaskGroup([task_id.new(1)]))
  let task = card_task(1, card_id.new(1), task_state.Available)
  let tree = activation.WorkTree(cards: [card], tasks: [task])

  let assert Ok(plan) =
    activation.activate_card(
      tree,
      card_id.new(1),
      manage_flow_actor(),
      now,
      healthy_pool_limit(20),
    )

  let assert 0 = plan.pool_impact.opened_by_action
  let assert True = plan.already_active
}

pub fn activation_excludes_closed_blocked_and_unclaimable_tasks_test() {
  let card =
    draft_card(
      1,
      option.None,
      card_structure.TaskGroup([
        task_id.new(1),
        task_id.new(2),
        task_id.new(3),
        task_id.new(4),
      ]),
    )
  let available = card_task(1, card_id.new(1), task_state.Available)
  let closed =
    card_task(2, card_id.new(1), task_state.Closed(task_state.Done, now, 7))
  let blocked =
    task_entity.Task(
      ..card_task(3, card_id.new(1), task_state.Available),
      blocked: True,
    )
  let no_capability =
    task_entity.Task(
      ..card_task(4, card_id.new(1), task_state.Available),
      capability_allowed: False,
    )
  let tree =
    activation.WorkTree(cards: [card], tasks: [
      available,
      closed,
      blocked,
      no_capability,
    ])

  let assert Ok(plan) =
    activation.activate_card(
      tree,
      card_id.new(1),
      manage_flow_actor(),
      now,
      healthy_pool_limit(20),
    )

  let assert 1 = plan.pool_impact.opened_by_action
}

pub fn activation_warns_when_pool_exceeds_project_healthy_limit_test() {
  let card =
    draft_card(1, option.None, card_structure.TaskGroup([task_id.new(1)]))
  let root = root_task(2, task_state.Available)
  let under_card = card_task(1, card_id.new(1), task_state.Available)
  let tree = activation.WorkTree(cards: [card], tasks: [root, under_card])

  let assert Ok(plan) =
    activation.activate_card(
      tree,
      card_id.new(1),
      manage_flow_actor(),
      now,
      healthy_pool_limit(1),
    )

  let assert 2 = plan.pool_impact.open_after
  let assert activation.ExceedsHealthyLimit = plan.pool_impact.health
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
    id: card_id.new(raw_id),
    project_id: project_id.new(1),
    parent: parent,
    structure: structure,
    execution_state: card_state.Active(
      activated_at: "2026-06-18T10:00:00Z",
      activated_by: user_id.new(7),
      source: card_state.DirectActivation,
    ),
  )
}

fn root_task(
  raw_id: Int,
  state: task_state.TaskExecutionState,
) -> task_entity.Task {
  task_entity.Task(
    id: task_id.new(raw_id),
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
  permissions.authorize_manage_flow_unchecked(user_id.new(7), project_id.new(1))
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
