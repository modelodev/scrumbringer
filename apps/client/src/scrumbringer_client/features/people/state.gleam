//// People feature state and derivation helpers.

import gleam/list
import gleam/option.{type Option, None, Some}

import domain/task.{type Task}
import domain/task_state
import domain/task_status
import scrumbringer_client/ui/badge

pub type Availability {
  Working
  Busy
  Free
}

pub type RowExpansion {
  Expanded
  Collapsed
}

pub type PersonStatus {
  PersonStatus(
    user_id: Int,
    label: String,
    availability: Availability,
    active_task: Option(Task),
    claimed_tasks: List(Task),
  )
}

pub fn derive_status(
  user_id: Int,
  label: String,
  tasks: List(Task),
) -> PersonStatus {
  let user_claimed =
    list.filter(tasks, fn(t) {
      case t.state {
        task_state.Claimed(claimed_by: claimed_by, ..) -> claimed_by == user_id
        _ -> False
      }
    })

  let active_task =
    list.find(user_claimed, fn(t) {
      case t.status {
        task_status.Claimed(task_status.Ongoing) -> True
        _ -> False
      }
    })
    |> option.from_result

  let claimed_tasks =
    list.filter(user_claimed, fn(t) {
      case t.status {
        task_status.Claimed(task_status.Taken) -> True
        _ -> False
      }
    })

  let availability = case active_task {
    Some(_) -> Working
    None ->
      case claimed_tasks != [] {
        True -> Busy
        False -> Free
      }
  }

  PersonStatus(
    user_id: user_id,
    label: label,
    availability: availability,
    active_task: active_task,
    claimed_tasks: claimed_tasks,
  )
}

pub fn badge_variant(availability: Availability) -> badge.BadgeVariant {
  case availability {
    Working -> badge.Primary
    Busy -> badge.Warning
    Free -> badge.Success
  }
}

pub fn toggle(expansion: RowExpansion) -> RowExpansion {
  case expansion {
    Expanded -> Collapsed
    Collapsed -> Expanded
  }
}
