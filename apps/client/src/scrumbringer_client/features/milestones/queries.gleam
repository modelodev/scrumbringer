import gleam/list
import gleam/option

import domain/card.{type Card}
import domain/milestone.{type Milestone, type MilestoneProgress, Active, Ready}
import domain/task.{type Task}

pub fn cards_for_milestone(cards: List(Card), milestone_id: Int) -> List(Card) {
  list.filter(cards, fn(card) { card.milestone_id == option.Some(milestone_id) })
}

pub fn tasks_for_card(tasks: List(Task), card_id: Int) -> List(Task) {
  list.filter(tasks, fn(task) { task.card_id == option.Some(card_id) })
}

pub fn loose_tasks_for_milestone(
  tasks: List(Task),
  milestone_id: Int,
) -> List(Task) {
  list.filter(tasks, fn(task) {
    task.milestone_id == option.Some(milestone_id)
    && task.card_id == option.None
  })
}

pub fn loose_tasks_count(tasks: List(Task), milestone_id: Int) -> Int {
  loose_tasks_for_milestone(tasks, milestone_id) |> list.length
}

pub fn tasks_in_cards_count(
  tasks: List(Task),
  cards: List(Card),
  milestone_id: Int,
) -> Int {
  list.count(tasks, fn(task) {
    task.card_id != option.None
    && effective_milestone_id(task, cards) == option.Some(milestone_id)
  })
}

pub fn blocked_tasks_count(
  tasks: List(Task),
  cards: List(Card),
  milestone_id: Int,
) -> Int {
  list.count(tasks, fn(task) {
    effective_milestone_id(task, cards) == option.Some(milestone_id)
    && task.blocked_count > 0
  })
}

pub fn effective_milestone_id(
  task: Task,
  cards: List(Card),
) -> option.Option(Int) {
  case task.milestone_id {
    option.Some(id) -> option.Some(id)
    option.None ->
      case task.card_id {
        option.Some(card_id) ->
          list.find(cards, fn(card) { card.id == card_id })
          |> option.from_result
          |> option.map(fn(card) { card.milestone_id })
          |> option.flatten
        option.None -> option.None
      }
  }
}

pub fn empty_cards_count(cards: List(Card), milestone_id: Int) -> Int {
  cards_for_milestone(cards, milestone_id)
  |> list.count(fn(card) { card.task_count == 0 })
}

pub fn ready_destination_milestones(
  items: List(MilestoneProgress),
  current_milestone_id: Int,
) -> List(Milestone) {
  items
  |> list.filter(fn(progress) {
    progress.milestone.state == Ready
    && progress.milestone.id != current_milestone_id
  })
  |> list.map(fn(progress) { progress.milestone })
}

pub fn is_ready_milestone(
  items: List(MilestoneProgress),
  milestone_id: Int,
) -> Bool {
  list.any(items, fn(progress) {
    progress.milestone.id == milestone_id && progress.milestone.state == Ready
  })
}

pub fn has_other_active_milestone(
  items: List(MilestoneProgress),
  milestone_id: Int,
) -> Bool {
  list.any(items, fn(progress) {
    progress.milestone.id != milestone_id && progress.milestone.state == Active
  })
}

pub fn progress_percentage(progress: MilestoneProgress) -> Int {
  let total = progress.cards_total + progress.tasks_total
  let done = progress.cards_completed + progress.tasks_completed

  case total <= 0 {
    True -> 0
    False -> done * 100 / total
  }
}
