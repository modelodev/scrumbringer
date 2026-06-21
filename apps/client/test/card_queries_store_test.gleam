import gleam/int
import gleam/option

import domain/card.{type Card, Card, Draft}
import domain/remote.{Loaded, NotAsked}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/state/normalized_store
import scrumbringer_client/utils/card_queries

fn make_card(id: Int, project_id: Int, title: String) -> Card {
  Card(
    id: id,
    project_id: project_id,
    parent_card_id: option.None,
    title: title,
    description: "",
    color: option.None,
    state: Draft,
    task_count: 0,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-02-01T00:00:00Z",
    due_date: option.None,
    has_new_notes: False,
  )
}

fn make_child_card(id: Int, parent_id: Int, title: String) -> Card {
  Card(..make_card(id, 10, title), parent_card_id: option.Some(parent_id))
}

fn make_task(id: Int, card_id: Int) -> Task {
  Task(
    id: id,
    project_id: 10,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Work", icon: "bolt"),
    ongoing_by: option.None,
    title: "Task " <> int_to_string(id),
    description: option.None,
    priority: 3,
    state: task_state.Available,
    status: task_status.Available,
    work_state: task_state.to_work_state(task_state.Available),
    created_by: 1,
    created_at: "2026-02-01T00:00:00Z",
    due_date: option.None,
    version: 1,
    parent_card_id: option.None,
    card_id: option.Some(card_id),
    card_title: option.None,
    card_color: option.None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn card_id(card: Card) -> Int {
  let Card(id: id, ..) = card
  id
}

pub fn find_card_uses_store_by_id_test() {
  let card_a = make_card(1, 10, "A")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a], card_id)

  let assert True =
    card_queries.find_card(store, NotAsked, 1) == option.Some(card_a)
}

pub fn get_project_cards_uses_store_index_test() {
  let card_a = make_card(1, 10, "A")
  let card_b = make_card(2, 10, "B")

  let store =
    normalized_store.new()
    |> normalized_store.upsert(10, [card_a, card_b], card_id)

  let assert True =
    card_queries.get_project_cards(store, Loaded([]), option.Some(10))
    == [card_a, card_b]
}

pub fn get_project_cards_ignores_missing_ids_test() {
  let assert [] =
    card_queries.get_project_cards(
      normalized_store.new(),
      NotAsked,
      option.Some(999),
    )
}

pub fn cards_for_project_scope_keeps_whole_tree_test() {
  let cards = [
    make_card(1, 10, "Root"),
    make_child_card(2, 1, "Feature"),
    make_child_card(3, 2, "Story"),
  ]

  let assert True =
    card_queries.cards_for_scope(
      cards,
      member_pool.PlanScopeProject,
      option.None,
      option.None,
    )
    == cards
}

pub fn cards_for_card_scope_keeps_selected_subtree_test() {
  let root = make_card(1, 10, "Root")
  let feature = make_child_card(2, 1, "Feature")
  let story = make_child_card(3, 2, "Story")
  let sibling = make_child_card(4, 1, "Sibling")

  let assert True =
    card_queries.cards_for_scope(
      [root, feature, story, sibling],
      member_pool.PlanScopeCard,
      option.None,
      option.Some(2),
    )
    == [feature, story]
}

pub fn row_cards_for_card_scope_prefers_direct_children_test() {
  let root = make_card(1, 10, "Root")
  let feature = make_child_card(2, 1, "Feature")
  let story = make_child_card(3, 2, "Story")

  let assert True =
    card_queries.row_cards_for_scope(
      [root, feature, story],
      member_pool.PlanScopeCard,
      option.None,
      option.Some(2),
    )
    == [story]
}

pub fn card_scope_defaults_to_closed_for_task_leaf_test() {
  let leaf = make_card(1, 10, "Leaf")

  let assert True =
    card_queries.closed_default_for_scope(
      [leaf],
      [make_task(1, 1)],
      member_pool.PlanScopeCard,
      option.Some(1),
    )
}

fn int_to_string(value: Int) -> String {
  value |> int.to_string
}
