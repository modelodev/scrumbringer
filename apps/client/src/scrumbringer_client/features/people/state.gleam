//// People feature state and derivation helpers.

import gleam/list
import gleam/option.{Some}

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
    active_tasks: List(Task),
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

  let active_tasks =
    list.filter(user_claimed, fn(t) { is_active_for_user(t, user_id) })

  let claimed_tasks =
    list.filter(user_claimed, fn(t) {
      case t.status {
        task_status.Claimed(task_status.Taken) ->
          !is_active_for_user(t, user_id)
        _ -> False
      }
    })

  let availability = case active_tasks != [] {
    True -> Working
    False ->
      case claimed_tasks != [] {
        True -> Busy
        False -> Free
      }
  }

  PersonStatus(
    user_id: user_id,
    label: label,
    availability: availability,
    active_tasks: active_tasks,
    claimed_tasks: claimed_tasks,
  )
}

fn is_active_for_user(task: Task, user_id: Int) -> Bool {
  case task.status {
    task_status.Claimed(task_status.Ongoing) -> True
    _ ->
      case task.ongoing_by {
        Some(task_status.OngoingBy(user_id: ongoing_user_id)) ->
          ongoing_user_id == user_id
        _ -> False
      }
  }
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
