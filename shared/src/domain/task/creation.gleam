//// Typed task creation entry points for card contexts.

import domain/card/entity as card_entity
import domain/card/state as card_state
import domain/card/structure as card_structure
import domain/project/id as project_id
import domain/project/permissions
import domain/task/entity as task_entity
import domain/task/id as task_id
import domain/task/placement
import domain/task/state as task_state
import gleam/result

pub type CreateTaskError {
  CardProjectMismatch
  CardIsNotDraft
  CardIsNotActive
  CardDoesNotAcceptTasks
}

pub fn create_task_in_draft_card(
  id: task_id.TaskId,
  card: card_entity.Card,
  actor: permissions.Authorized(permissions.ManageFlow),
) -> Result(task_entity.Task, CreateTaskError) {
  use Nil <- result.try(require_same_project(
    card,
    permissions.project_id(actor),
  ))
  case card.execution_state {
    card_state.Draft -> create_card_task_if_task_group(id, card)
    card_state.Active(..) | card_state.Closed(..) -> Error(CardIsNotDraft)
  }
}

pub fn create_task_in_active_task_group(
  id: task_id.TaskId,
  card: card_entity.Card,
  actor: permissions.Authorized(permissions.ExecuteWork),
) -> Result(task_entity.Task, CreateTaskError) {
  use Nil <- result.try(require_same_project(
    card,
    permissions.project_id(actor),
  ))
  case card.execution_state {
    card_state.Active(..) -> create_card_task_if_task_group(id, card)
    card_state.Draft | card_state.Closed(..) -> Error(CardIsNotActive)
  }
}

fn create_card_task_if_task_group(
  id: task_id.TaskId,
  card: card_entity.Card,
) -> Result(task_entity.Task, CreateTaskError) {
  case card.structure {
    card_structure.Empty | card_structure.TaskGroup(_) ->
      Ok(task_entity.Task(
        id: id,
        project_id: card.project_id,
        placement: placement.UnderCard(card.id),
        execution_state: task_state.Available,
        blocked: False,
        capability_allowed: True,
      ))
    card_structure.CardGroup(_) -> Error(CardDoesNotAcceptTasks)
  }
}

fn require_same_project(
  card: card_entity.Card,
  actor_project_id: project_id.ProjectId,
) -> Result(Nil, CreateTaskError) {
  case card.project_id == actor_project_id {
    True -> Ok(Nil)
    False -> Error(CardProjectMismatch)
  }
}
