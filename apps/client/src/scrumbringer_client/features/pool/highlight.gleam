//// Member pool highlight state transitions.

import gleam/option

import domain/task.{type Task}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/blocking
import scrumbringer_client/helpers/lookup as helpers_lookup

pub fn clear(model: member_pool.Model) -> member_pool.Model {
  member_pool.Model(..model, member_highlight_state: member_pool.NoHighlight)
}

pub fn created(model: member_pool.Model, task_id: Int) -> member_pool.Model {
  member_pool.Model(
    ..model,
    member_highlight_state: member_pool.CreatedHighlight(task_id),
  )
}

pub fn expire(model: member_pool.Model, task_id: Int) -> member_pool.Model {
  let next_highlight = case model.member_highlight_state {
    member_pool.CreatedHighlight(id) if id == task_id -> member_pool.NoHighlight
    state -> state
  }

  member_pool.Model(..model, member_highlight_state: next_highlight)
}

pub fn blocking_for_task(
  model: member_pool.Model,
  task_id: Int,
) -> member_pool.Model {
  let next_state =
    blocking_state_for_task(
      model,
      task_id,
      helpers_lookup.find_task_by_id(model.member_tasks, task_id),
    )

  member_pool.Model(..model, member_highlight_state: next_state)
}

fn blocking_state_for_task(
  model: member_pool.Model,
  task_id: Int,
  task: option.Option(Task),
) -> member_pool.HighlightState {
  case task {
    option.Some(task) -> {
      let blocker_ids = blocking.open_dependency_ids(task)
      case blocker_ids {
        [] -> member_pool.NoHighlight
        _ -> {
          let hidden_count =
            blocking.hidden_count(model.member_tasks, blocker_ids)
          member_pool.BlockingHighlight(task_id, blocker_ids, hidden_count)
        }
      }
    }
    option.None -> member_pool.NoHighlight
  }
}
