import gleam/int
import gleam/list
import gleam/option as opt

import domain/card.{type Card, Card, Pendiente}
import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Milestone,
  MilestoneProgress, Ready,
}
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/milestones/queries

fn assert_equal(actual, expected) {
  let assert True = actual == expected
}

fn milestone(id: Int, state: MilestoneState) -> MilestoneProgress {
  MilestoneProgress(
    milestone: Milestone(
      id: id,
      project_id: 1,
      name: "Milestone " <> int.to_string(id),
      description: opt.None,
      state: state,
      position: id,
      created_by: 1,
      created_at: "2026-02-06T00:00:00Z",
      activated_at: opt.None,
      completed_at: opt.None,
    ),
    cards_total: 0,
    cards_completed: 0,
    tasks_total: 0,
    tasks_completed: 0,
  )
}

fn milestone_progress(
  id: Int,
  cards_total: Int,
  cards_completed: Int,
  tasks_total: Int,
  tasks_completed: Int,
) -> MilestoneProgress {
  let progress = milestone(id, Ready)

  MilestoneProgress(
    ..progress,
    cards_total: cards_total,
    cards_completed: cards_completed,
    tasks_total: tasks_total,
    tasks_completed: tasks_completed,
  )
}

fn card(id: Int, milestone_id: Int, task_count: Int) -> Card {
  Card(
    id: id,
    project_id: 1,
    milestone_id: opt.Some(milestone_id),
    title: "Card " <> int.to_string(id),
    description: "",
    color: opt.None,
    state: Pendiente,
    task_count: task_count,
    completed_count: 0,
    created_by: 1,
    created_at: "2026-02-06T00:00:00Z",
    has_new_notes: False,
  )
}

fn task(
  id: Int,
  milestone_id: opt.Option(Int),
  card_id: opt.Option(Int),
  blocked_count: Int,
) -> Task {
  let state = task_state.Available

  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Task", icon: "check"),
    ongoing_by: opt.None,
    title: "Task " <> int.to_string(id),
    description: opt.None,
    priority: 1,
    state: state,
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-02-06T00:00:00Z",
    version: 1,
    milestone_id: milestone_id,
    card_id: card_id,
    card_title: opt.None,
    card_color: opt.None,
    has_new_notes: False,
    blocked_count: blocked_count,
    dependencies: [],
  )
}

pub fn milestone_queries_count_tasks_and_cards_test() {
  let cards = [card(10, 1, 0), card(11, 2, 3), card(12, 1, 2)]
  let tasks = [
    task(1, opt.Some(1), opt.None, 0),
    task(2, opt.None, opt.Some(10), 1),
    task(3, opt.None, opt.Some(11), 0),
  ]

  queries.loose_tasks_count(tasks, 1) |> assert_equal(1)
  queries.blocked_tasks_count(tasks, cards, 1) |> assert_equal(1)
  queries.empty_cards_count(cards, 1) |> assert_equal(1)
  queries.cards_without_progress_count(cards, 1) |> assert_equal(1)
}

pub fn milestone_queries_resolve_destination_and_active_state_test() {
  let items = [milestone(1, Ready), milestone(2, Ready), milestone(3, Active)]

  queries.ready_destination_milestones(items, 1)
  |> list.length
  |> assert_equal(1)

  queries.is_ready_milestone(items, 1) |> assert_equal(True)
  queries.has_other_active_milestone(items, 1) |> assert_equal(True)
}

pub fn milestone_queries_progress_percentage_counts_cards_and_tasks_test() {
  queries.progress_percentage(milestone_progress(1, 3, 2, 2, 1))
  |> assert_equal(60)
}

pub fn milestone_queries_progress_percentage_returns_zero_without_work_test() {
  queries.progress_percentage(milestone_progress(1, 0, 0, 0, 0))
  |> assert_equal(0)
}
