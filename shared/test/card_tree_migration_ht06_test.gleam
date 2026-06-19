import gleam/list
import gleam/option

import domain/card/id as card_id
import domain/card/migration
import domain/card/state as card_state
import domain/project/id as project_id
import domain/task/id as task_id
import domain/task/placement
import domain/task/state as task_state
import domain/user/id as user_id

const now = "2026-06-19T10:00:00Z"

pub fn migration_maps_milestone_to_root_card_test() {
  let snapshot =
    migration.LegacySnapshot(
      milestones: [ready_milestone(10, "Release 1")],
      cards: [],
      tasks: [],
      next_generated_card_id: 1000,
      final_schema_already_applied: False,
    )

  let assert Ok(plan) = migration.plan(snapshot, now)
  let assert option.Some(card) = card_for(plan, card_id.new(1000))
  let assert option.None = card.parent
  let assert "Release 1" = card.title
  let assert card_state.Draft = card.execution_state
}

pub fn migration_maps_existing_card_to_level_2_card_test() {
  let snapshot =
    migration.LegacySnapshot(
      milestones: [ready_milestone(10, "Release 1")],
      cards: [legacy_card(20, option.Some(10), "Feature")],
      tasks: [],
      next_generated_card_id: 1000,
      final_schema_already_applied: False,
    )

  let assert Ok(plan) = migration.plan(snapshot, now)
  let assert option.Some(card) = card_for(plan, card_id.new(20))
  let assert True = card.parent == option.Some(card_id.new(1000))
}

pub fn migration_maps_task_without_card_or_milestone_to_root_pool_test() {
  let task =
    legacy_task(30, option.None, option.None, migration.LegacyAvailable)
  let snapshot =
    migration.LegacySnapshot(
      milestones: [],
      cards: [],
      tasks: [task],
      next_generated_card_id: 1000,
      final_schema_already_applied: False,
    )

  let assert Ok(plan) = migration.plan(snapshot, now)
  let assert option.Some(task) = task_for(plan, task_id.new(30))
  let assert placement.RootPool = task.placement
}

pub fn migration_maps_task_under_milestone_without_card_test() {
  let task =
    legacy_task(30, option.None, option.Some(10), migration.LegacyAvailable)
  let snapshot =
    migration.LegacySnapshot(
      milestones: [ready_milestone(10, "Release 1")],
      cards: [],
      tasks: [task],
      next_generated_card_id: 1000,
      final_schema_already_applied: False,
    )

  let assert Ok(plan) = migration.plan(snapshot, now)
  let assert option.Some(task) = task_for(plan, task_id.new(30))
  let assert placement.UnderCard(parent_id) = task.placement
  let assert True = parent_id == card_id.new(1000)
}

pub fn migration_creates_grouping_card_when_node_would_mix_children_test() {
  let snapshot =
    migration.LegacySnapshot(
      milestones: [ready_milestone(10, "Release 1")],
      cards: [legacy_card(20, option.Some(10), "Feature")],
      tasks: [
        legacy_task(30, option.None, option.Some(10), migration.LegacyAvailable),
      ],
      next_generated_card_id: 1000,
      final_schema_already_applied: False,
    )

  let assert Ok(plan) = migration.plan(snapshot, now)
  let assert option.Some(grouping) = card_for(plan, card_id.new(1001))
  let assert "Trabajo directo" = grouping.title
  let assert True = grouping.parent == option.Some(card_id.new(1000))
  let assert option.Some(task) = task_for(plan, task_id.new(30))
  let assert placement.UnderCard(parent_id) = task.placement
  let assert True = parent_id == card_id.new(1001)
  let assert 1 = plan.report.grouping_cards_created
}

pub fn migration_maps_completed_task_to_closed_done_test() {
  let task =
    legacy_task(30, option.None, option.None, migration.LegacyCompleted)
  let snapshot =
    migration.LegacySnapshot(
      milestones: [],
      cards: [],
      tasks: [task],
      next_generated_card_id: 1000,
      final_schema_already_applied: False,
    )

  let assert Ok(plan) = migration.plan(snapshot, now)
  let assert option.Some(migrated) = task_for(plan, task_id.new(30))
  let assert task_state.Closed(reason, _, closed_by) = migrated.execution_state
  let assert task_state.Done = reason
  let assert True = closed_by == user_id.new(7)
}

pub fn migration_removes_milestone_columns_from_final_schema_test() {
  let contract = migration.final_schema_contract()

  let assert False = list.contains(contract.tables, "milestones")
  let assert False = list.contains(contract.card_columns, "milestone_id")
  let assert False = list.contains(contract.task_columns, "milestone_id")
  let assert False =
    list.contains(contract.constraints, "task_milestone_exclusive")
}

pub fn migration_maps_ready_active_and_completed_milestone_states_test() {
  let snapshot =
    migration.LegacySnapshot(
      milestones: [
        ready_milestone(10, "Ready"),
        active_milestone(11, "Active"),
        completed_milestone(12, "Completed"),
      ],
      cards: [],
      tasks: [],
      next_generated_card_id: 1000,
      final_schema_already_applied: False,
    )

  let assert Ok(plan) = migration.plan(snapshot, now)
  let assert option.Some(ready) = card_for(plan, card_id.new(1000))
  let assert option.Some(active) = card_for(plan, card_id.new(1001))
  let assert option.Some(completed) = card_for(plan, card_id.new(1002))

  let assert card_state.Draft = ready.execution_state
  let assert card_state.Active(..) = active.execution_state
  let assert card_state.Closed(..) = completed.execution_state
}

pub fn migration_reports_inconsistent_completed_milestone_test() {
  let snapshot =
    migration.LegacySnapshot(
      milestones: [
        migration.LegacyMilestone(
          id: 10,
          project_id: project_id.new(1),
          name: "Broken",
          description: "",
          state: migration.LegacyMilestoneCompleted,
          created_by: user_id.new(7),
          activated_at: option.Some(now),
          completed_at: option.None,
        ),
      ],
      cards: [],
      tasks: [],
      next_generated_card_id: 1000,
      final_schema_already_applied: False,
    )

  let assert Ok(plan) = migration.plan(snapshot, now)
  let assert True = plan.report.inconsistent_milestones == [card_id.new(1000)]
}

pub fn migration_is_protected_against_double_execution_test() {
  let snapshot =
    migration.LegacySnapshot(
      milestones: [],
      cards: [],
      tasks: [],
      next_generated_card_id: 1000,
      final_schema_already_applied: True,
    )

  let assert Error(migration.AlreadyMigrated) = migration.plan(snapshot, now)
}

fn ready_milestone(raw_id: Int, name: String) -> migration.LegacyMilestone {
  migration.LegacyMilestone(
    id: raw_id,
    project_id: project_id.new(1),
    name: name,
    description: "",
    state: migration.LegacyMilestoneReady,
    created_by: user_id.new(7),
    activated_at: option.None,
    completed_at: option.None,
  )
}

fn active_milestone(raw_id: Int, name: String) -> migration.LegacyMilestone {
  migration.LegacyMilestone(
    id: raw_id,
    project_id: project_id.new(1),
    name: name,
    description: "",
    state: migration.LegacyMilestoneActive,
    created_by: user_id.new(7),
    activated_at: option.Some(now),
    completed_at: option.None,
  )
}

fn completed_milestone(raw_id: Int, name: String) -> migration.LegacyMilestone {
  migration.LegacyMilestone(
    id: raw_id,
    project_id: project_id.new(1),
    name: name,
    description: "",
    state: migration.LegacyMilestoneCompleted,
    created_by: user_id.new(7),
    activated_at: option.Some(now),
    completed_at: option.Some(now),
  )
}

fn legacy_card(
  raw_id: Int,
  milestone_id: option.Option(Int),
  title: String,
) -> migration.LegacyCard {
  migration.LegacyCard(
    id: raw_id,
    project_id: project_id.new(1),
    milestone_id: milestone_id,
    title: title,
    description: "",
    created_by: user_id.new(7),
  )
}

fn legacy_task(
  raw_id: Int,
  card_id: option.Option(Int),
  milestone_id: option.Option(Int),
  status: migration.LegacyTaskStatus,
) -> migration.LegacyTask {
  migration.LegacyTask(
    id: raw_id,
    project_id: project_id.new(1),
    card_id: card_id,
    milestone_id: milestone_id,
    status: status,
    created_by: user_id.new(7),
    claimed_by: option.None,
    claimed_at: option.None,
    completed_at: option.Some(now),
  )
}

fn card_for(
  plan: migration.MigrationPlan,
  id: card_id.CardId,
) -> option.Option(migration.MigratedCard) {
  plan.cards
  |> list.find(fn(card) { card.id == id })
  |> result_to_option
}

fn task_for(
  plan: migration.MigrationPlan,
  id: task_id.TaskId,
) -> option.Option(migration.MigratedTask) {
  plan.tasks
  |> list.find(fn(task) { task.id == id })
  |> result_to_option
}

fn result_to_option(result: Result(a, b)) -> option.Option(a) {
  case result {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}
