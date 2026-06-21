import gleam/option

import domain/card/entity as card_entity
import domain/card/id as card_id
import domain/card/state as card_state
import domain/card/structure as card_structure
import domain/project/id as project_id
import domain/project/permissions
import domain/task/id as task_id
import domain/user/id as user_id

pub fn empty_card_accepts_first_child_card_test() {
  let parent = draft_card(card_id.new(1), project_id.new(1), option.None)
  let child_id = card_id.new(2)

  let assert Ok(updated) =
    card_entity.add_card_child(parent, project_id.new(1), child_id)
  let assert card_structure.CardGroup(children) = updated.structure
  let assert True = children == [child_id]
}

pub fn empty_card_accepts_first_child_task_test() {
  let parent = draft_card(card_id.new(1), project_id.new(1), option.None)
  let child_id = task_id.new(2)

  let assert Ok(updated) =
    card_entity.add_task_child(parent, project_id.new(1), child_id)
  let assert card_structure.TaskGroup(children) = updated.structure
  let assert True = children == [child_id]
}

pub fn card_group_rejects_task_child_test() {
  let parent =
    draft_card(card_id.new(1), project_id.new(1), option.None)
    |> card_entity.add_card_child(project_id.new(1), card_id.new(2))

  let assert Ok(parent) = parent
  let assert Error(card_entity.CannotAddTaskToCardGroup) =
    card_entity.add_task_child(parent, project_id.new(1), task_id.new(3))
}

pub fn task_group_rejects_card_child_test() {
  let parent =
    draft_card(card_id.new(1), project_id.new(1), option.None)
    |> card_entity.add_task_child(project_id.new(1), task_id.new(2))

  let assert Ok(parent) = parent
  let assert Error(card_entity.CannotAddCardToTaskGroup) =
    card_entity.add_card_child(parent, project_id.new(1), card_id.new(3))
}

pub fn flat_children_with_cards_and_tasks_are_rejected_test() {
  let assert Error(card_structure.MixedChildKinds) =
    card_structure.from_children([card_id.new(2)], [task_id.new(3)])
}

pub fn flat_children_are_reconstructed_as_one_child_kind_test() {
  let child_card_id = card_id.new(2)
  let child_task_id = task_id.new(3)

  let assert Ok(card_structure.Empty) = card_structure.from_children([], [])
  let assert Ok(card_group) = card_structure.from_children([child_card_id], [])
  let assert card_structure.CardGroup(card_children) = card_group
  let assert True = card_children == [child_card_id]

  let assert Ok(task_group) = card_structure.from_children([], [child_task_id])
  let assert card_structure.TaskGroup(task_children) = task_group
  let assert True = task_children == [child_task_id]
}

pub fn closed_card_rejects_new_children_test() {
  let parent = closed_card(card_id.new(1), project_id.new(1), option.None)

  let assert Error(card_entity.CannotAddChildToClosedCard) =
    card_entity.add_task_child(parent, project_id.new(1), task_id.new(2))

  let assert Error(card_entity.CannotAddChildToClosedCard) =
    card_entity.add_card_child(parent, project_id.new(1), card_id.new(2))
}

pub fn child_from_other_project_is_rejected_test() {
  let parent = draft_card(card_id.new(1), project_id.new(1), option.None)

  let assert Error(card_entity.ChildFromOtherProject) =
    card_entity.add_card_child(parent, project_id.new(2), card_id.new(2))

  let assert Error(card_entity.ChildFromOtherProject) =
    card_entity.add_task_child(parent, project_id.new(2), task_id.new(2))
}

pub fn moving_card_under_descendant_is_rejected_test() {
  let root = draft_card(card_id.new(1), project_id.new(1), option.None)
  let child =
    draft_card(card_id.new(2), project_id.new(1), option.Some(card_id.new(1)))

  let hierarchy = card_entity.CardHierarchy([root, child])

  let auth =
    permissions.authorize_manage_structure_unchecked(
      user_id.new(7),
      project_id.new(1),
    )
  let assert Error(card_entity.MoveWouldCreateCycle) =
    card_entity.move_card_to_parent(
      root,
      auth,
      option.Some(card_id.new(2)),
      hierarchy,
    )
}

fn draft_card(
  id: card_id.CardId,
  project: project_id.ProjectId,
  parent: option.Option(card_id.CardId),
) -> card_entity.Card {
  card_entity.Card(
    id: id,
    project_id: project,
    parent: parent,
    structure: card_structure.Empty,
    execution_state: card_state.Draft,
  )
}

fn closed_card(
  id: card_id.CardId,
  project: project_id.ProjectId,
  parent: option.Option(card_id.CardId),
) -> card_entity.Card {
  card_entity.Card(
    id: id,
    project_id: project,
    parent: parent,
    structure: card_structure.Empty,
    execution_state: card_state.Closed(
      reason: card_state.ManuallyClosed,
      closed_at: "2026-06-19T10:00:00Z",
      closed_by: card_state.ClosedByUser(user_id.new(7)),
    ),
  )
}
