//// Pure migration planner from legacy milestones/cards/tasks to card tree leaves.

import domain/card/id as card_id
import domain/card/state as card_state
import domain/project/id as project_id
import domain/task/id as task_id
import domain/task/placement
import domain/task/state as task_state
import domain/user/id as user_id
import gleam/list
import gleam/option.{type Option, None, Some}

pub type LegacySnapshot {
  LegacySnapshot(
    milestones: List(LegacyMilestone),
    cards: List(LegacyCard),
    tasks: List(LegacyTask),
    next_generated_card_id: Int,
    final_schema_already_applied: Bool,
  )
}

pub type LegacyMilestone {
  LegacyMilestone(
    id: Int,
    project_id: project_id.ProjectId,
    name: String,
    description: String,
    state: LegacyMilestoneState,
    created_by: user_id.UserId,
    activated_at: Option(String),
    completed_at: Option(String),
  )
}

pub type LegacyMilestoneState {
  LegacyMilestoneReady
  LegacyMilestoneActive
  LegacyMilestoneCompleted
}

pub type LegacyCard {
  LegacyCard(
    id: Int,
    project_id: project_id.ProjectId,
    milestone_id: Option(Int),
    title: String,
    description: String,
    created_by: user_id.UserId,
  )
}

pub type LegacyTask {
  LegacyTask(
    id: Int,
    project_id: project_id.ProjectId,
    card_id: Option(Int),
    milestone_id: Option(Int),
    status: LegacyTaskStatus,
    created_by: user_id.UserId,
    claimed_by: Option(user_id.UserId),
    claimed_at: Option(String),
    completed_at: Option(String),
  )
}

pub type LegacyTaskStatus {
  LegacyAvailable
  LegacyClaimed
  LegacyCompleted
}

pub type MigratedCard {
  MigratedCard(
    id: card_id.CardId,
    project_id: project_id.ProjectId,
    parent: Option(card_id.CardId),
    title: String,
    description: String,
    execution_state: card_state.CardExecutionState,
  )
}

pub type MigratedTask {
  MigratedTask(
    id: task_id.TaskId,
    project_id: project_id.ProjectId,
    placement: placement.TaskPlacement,
    execution_state: task_state.TaskExecutionState,
  )
}

pub type MigrationPlan {
  MigrationPlan(
    cards: List(MigratedCard),
    tasks: List(MigratedTask),
    report: MigrationReport,
  )
}

pub type MigrationReport {
  MigrationReport(
    grouping_cards_created: Int,
    inconsistent_milestones: List(card_id.CardId),
  )
}

pub type MigrationError {
  AlreadyMigrated
}

pub type FinalSchemaContract {
  FinalSchemaContract(
    tables: List(String),
    card_columns: List(String),
    task_columns: List(String),
    constraints: List(String),
  )
}

type RootCard {
  RootCard(milestone_id: Int, card: MigratedCard)
}

pub fn plan(
  snapshot: LegacySnapshot,
  now: String,
) -> Result(MigrationPlan, MigrationError) {
  case snapshot.final_schema_already_applied {
    True -> Error(AlreadyMigrated)
    False -> Ok(build_plan(snapshot, now))
  }
}

pub fn final_schema_contract() -> FinalSchemaContract {
  FinalSchemaContract(
    tables: [
      "cards",
      "tasks",
      "project_settings",
      "project_card_depth_names",
    ],
    card_columns: [
      "id",
      "project_id",
      "parent_card_id",
      "title",
      "description",
      "color",
      "execution_state",
      "activated_at",
      "activated_by",
      "activation_source",
      "closed_at",
      "closed_by",
      "closed_reason",
      "due_date",
      "created_by",
      "created_at",
    ],
    task_columns: [
      "id",
      "project_id",
      "card_id",
      "capability_id",
      "execution_state",
      "claimed_by",
      "claimed_at",
      "claimed_mode",
      "closed_at",
      "closed_by",
      "closed_reason",
      "due_date",
    ],
    constraints: [
      "cards_parent_card_fk",
      "tasks_project_card_fk",
      "tasks_execution_state_check",
    ],
  )
}

fn build_plan(snapshot: LegacySnapshot, now: String) -> MigrationPlan {
  let LegacySnapshot(
    milestones: milestones,
    cards: legacy_cards,
    tasks: legacy_tasks,
    next_generated_card_id: next_generated_card_id,
    ..,
  ) = snapshot

  let root_card_map =
    milestone_root_cards_for(milestones, next_generated_card_id, now)
  let root_cards = list.map(root_card_map, fn(root) { root.card })
  let next_grouping_card_id =
    next_generated_card_id + list.length(root_card_map)
  let grouping_cards =
    grouping_cards_for(
      milestones,
      legacy_cards,
      legacy_tasks,
      root_card_map,
      next_grouping_card_id,
    )
  let cards =
    list.append(
      list.append(
        root_cards,
        list.map(legacy_cards, legacy_card_to_card(_, root_card_map)),
      ),
      grouping_cards,
    )
  let tasks =
    list.map(legacy_tasks, fn(task) {
      legacy_task_to_task(task, root_card_map, grouping_cards, now)
    })
  let inconsistent_milestones =
    milestones
    |> list.filter(is_inconsistent_completed_milestone)
    |> list.map(fn(milestone) { root_card_id(milestone.id, root_card_map) })

  MigrationPlan(
    cards: cards,
    tasks: tasks,
    report: MigrationReport(
      grouping_cards_created: list.length(grouping_cards),
      inconsistent_milestones: inconsistent_milestones,
    ),
  )
}

fn milestone_root_cards_for(
  milestones: List(LegacyMilestone),
  next_generated_card_id: Int,
  now: String,
) -> List(RootCard) {
  do_milestone_root_cards_for(milestones, next_generated_card_id, now, [])
}

fn do_milestone_root_cards_for(
  milestones: List(LegacyMilestone),
  next_id: Int,
  now: String,
  acc: List(RootCard),
) -> List(RootCard) {
  case milestones {
    [] -> list.reverse(acc)
    [milestone, ..rest] -> {
      let card = milestone_to_card(milestone, card_id.new(next_id), now)
      do_milestone_root_cards_for(rest, next_id + 1, now, [
        RootCard(milestone_id: milestone.id, card: card),
        ..acc
      ])
    }
  }
}

fn milestone_to_card(
  milestone: LegacyMilestone,
  id: card_id.CardId,
  now: String,
) -> MigratedCard {
  MigratedCard(
    id: id,
    project_id: milestone.project_id,
    parent: None,
    title: milestone.name,
    description: milestone.description,
    execution_state: milestone_state_to_card_state(milestone, now),
  )
}

fn legacy_card_to_card(
  card: LegacyCard,
  root_cards: List(RootCard),
) -> MigratedCard {
  MigratedCard(
    id: card_id.new(card.id),
    project_id: card.project_id,
    parent: option_milestone_to_card_id(card.milestone_id, root_cards),
    title: card.title,
    description: card.description,
    execution_state: card_state.Draft,
  )
}

fn legacy_task_to_task(
  task: LegacyTask,
  root_cards: List(RootCard),
  grouping_cards: List(MigratedCard),
  now: String,
) -> MigratedTask {
  MigratedTask(
    id: task_id.new(task.id),
    project_id: task.project_id,
    placement: task_placement(task, root_cards, grouping_cards),
    execution_state: task_status_to_state(task, now),
  )
}

fn milestone_state_to_card_state(
  milestone: LegacyMilestone,
  now: String,
) -> card_state.CardExecutionState {
  case milestone.state {
    LegacyMilestoneReady -> card_state.Draft
    LegacyMilestoneActive ->
      card_state.Active(
        activated_at: option_string_or(milestone.activated_at, now),
        activated_by: milestone.created_by,
        source: card_state.DirectActivation,
      )
    LegacyMilestoneCompleted ->
      card_state.Closed(
        reason: card_state.Rollup,
        closed_at: option_string_or(milestone.completed_at, now),
        closed_by: card_state.ClosedBySystem,
      )
  }
}

fn task_status_to_state(
  task: LegacyTask,
  now: String,
) -> task_state.TaskExecutionState {
  case task.status {
    LegacyAvailable -> task_state.Available
    LegacyClaimed ->
      task_state.Claimed(
        claimed_by: option_user_or(task.claimed_by, task.created_by),
        claimed_at: option_string_or(task.claimed_at, now),
        mode: task_state.Taken,
      )
    LegacyCompleted ->
      task_state.Closed(
        reason: task_state.Done,
        closed_at: option_string_or(task.completed_at, now),
        closed_by: task.created_by,
      )
  }
}

fn task_placement(
  task: LegacyTask,
  root_cards: List(RootCard),
  grouping_cards: List(MigratedCard),
) -> placement.TaskPlacement {
  case task.card_id, task.milestone_id {
    Some(id), _ -> placement.UnderCard(card_id.new(id))
    None, Some(milestone_id) ->
      placement.UnderCard(task_milestone_parent(
        milestone_id,
        root_cards,
        grouping_cards,
      ))
    None, None -> placement.RootPool
  }
}

fn task_milestone_parent(
  milestone_id: Int,
  root_cards: List(RootCard),
  grouping_cards: List(MigratedCard),
) -> card_id.CardId {
  let root_id = root_card_id(milestone_id, root_cards)
  case list.find(grouping_cards, fn(card) { card.parent == Some(root_id) }) {
    Ok(card) -> card.id
    Error(_) -> root_id
  }
}

fn grouping_cards_for(
  milestones: List(LegacyMilestone),
  legacy_cards: List(LegacyCard),
  legacy_tasks: List(LegacyTask),
  root_cards: List(RootCard),
  next_generated_card_id: Int,
) -> List(MigratedCard) {
  do_grouping_cards_for(
    milestones,
    legacy_cards,
    legacy_tasks,
    root_cards,
    next_generated_card_id,
    [],
  )
}

fn do_grouping_cards_for(
  milestones: List(LegacyMilestone),
  legacy_cards: List(LegacyCard),
  legacy_tasks: List(LegacyTask),
  root_cards: List(RootCard),
  next_id: Int,
  acc: List(MigratedCard),
) -> List(MigratedCard) {
  case milestones {
    [] -> list.reverse(acc)
    [milestone, ..rest] -> {
      case milestone_needs_grouping(milestone.id, legacy_cards, legacy_tasks) {
        True -> {
          let grouping =
            MigratedCard(
              id: card_id.new(next_id),
              project_id: milestone.project_id,
              parent: Some(root_card_id(milestone.id, root_cards)),
              title: "Trabajo directo",
              description: "",
              execution_state: card_state.Draft,
            )
          do_grouping_cards_for(
            rest,
            legacy_cards,
            legacy_tasks,
            root_cards,
            next_id + 1,
            [grouping, ..acc],
          )
        }
        False ->
          do_grouping_cards_for(
            rest,
            legacy_cards,
            legacy_tasks,
            root_cards,
            next_id,
            acc,
          )
      }
    }
  }
}

fn root_card_id(milestone_id: Int, root_cards: List(RootCard)) -> card_id.CardId {
  case list.find(root_cards, fn(root) { root.milestone_id == milestone_id }) {
    Ok(root) -> root.card.id
    Error(_) -> card_id.new(milestone_id)
  }
}

fn option_milestone_to_card_id(
  value: Option(Int),
  root_cards: List(RootCard),
) -> Option(card_id.CardId) {
  case value {
    Some(milestone_id) -> Some(root_card_id(milestone_id, root_cards))
    None -> None
  }
}

fn milestone_needs_grouping(
  milestone_id: Int,
  legacy_cards: List(LegacyCard),
  legacy_tasks: List(LegacyTask),
) -> Bool {
  milestone_has_cards(milestone_id, legacy_cards)
  && milestone_has_direct_tasks(milestone_id, legacy_tasks)
}

fn milestone_has_cards(milestone_id: Int, legacy_cards: List(LegacyCard)) {
  list.any(legacy_cards, fn(card) { card.milestone_id == Some(milestone_id) })
}

fn milestone_has_direct_tasks(milestone_id: Int, legacy_tasks: List(LegacyTask)) {
  list.any(legacy_tasks, fn(task) {
    task.card_id == None && task.milestone_id == Some(milestone_id)
  })
}

fn is_inconsistent_completed_milestone(milestone: LegacyMilestone) -> Bool {
  case milestone.state, milestone.activated_at, milestone.completed_at {
    LegacyMilestoneCompleted, Some(_), Some(_) -> False
    LegacyMilestoneCompleted, _, _ -> True
    _, _, _ -> False
  }
}

fn option_string_or(value: Option(String), fallback: String) -> String {
  case value {
    Some(inner) -> inner
    None -> fallback
  }
}

fn option_user_or(
  value: Option(user_id.UserId),
  fallback: user_id.UserId,
) -> user_id.UserId {
  case value {
    Some(inner) -> inner
    None -> fallback
  }
}
