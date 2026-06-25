//// People feature state and derivation helpers.

import gleam/list
import gleam/order
import gleam/string

import domain/task as domain_task
import domain/task/state as task_state
import scrumbringer_client/ui/badge

const load_warning_claimed_threshold = 4

pub type PeopleVisibilityFilter {
  ShowEveryone
  ShowWithWork
  ShowAttention
  ShowFree
}

pub type PeopleSort {
  SortByAttention
  SortByName
  SortByClaimedCount
}

pub type PersonWorkState {
  WorkingNow
  HasClaimedWork
  BlockedWork
  FreeInScope
}

pub type PersonAttentionSignal {
  BlockedTask(task_id: Int)
  HighClaimedLoad(claimed_count: Int)
}

pub type RowExpansion {
  Expanded
  Collapsed
}

pub type PersonStatus {
  PersonStatus(
    user_id: Int,
    label: String,
    work_state: PersonWorkState,
    active_tasks: List(domain_task.Task),
    claimed_tasks: List(domain_task.Task),
    signals: List(PersonAttentionSignal),
  )
}

pub fn derive_status(
  user_id: Int,
  label: String,
  tasks: List(domain_task.Task),
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
      case t.state {
        task_state.Claimed(mode: task_state.Taken, ..) -> True
        task_state.Available
        | task_state.Claimed(mode: task_state.Ongoing, ..)
        | task_state.Closed(..) -> False
      }
    })

  let signals = attention_signals(list.append(active_tasks, claimed_tasks))

  let work_state = case signals {
    [BlockedTask(_), ..] -> BlockedWork
    _ ->
      case active_tasks != [] {
        True -> WorkingNow
        False ->
          case claimed_tasks != [] {
            True -> HasClaimedWork
            False -> FreeInScope
          }
      }
  }

  PersonStatus(
    user_id: user_id,
    label: label,
    work_state: work_state,
    active_tasks: active_tasks,
    claimed_tasks: claimed_tasks,
    signals: signals,
  )
}

pub fn has_work(person: PersonStatus) -> Bool {
  person.active_tasks != [] || person.claimed_tasks != []
}

pub fn has_attention(person: PersonStatus) -> Bool {
  person.signals != []
}

pub fn claimed_work_count(person: PersonStatus) -> Int {
  list.length(person.active_tasks) + list.length(person.claimed_tasks)
}

pub fn apply_visibility_filter(
  people: List(PersonStatus),
  filter: PeopleVisibilityFilter,
) -> List(PersonStatus) {
  case filter {
    ShowEveryone -> people
    ShowWithWork -> list.filter(people, has_work)
    ShowAttention -> list.filter(people, has_attention)
    ShowFree -> list.filter(people, fn(person) { !has_work(person) })
  }
}

pub fn sort_people(
  people: List(PersonStatus),
  sort: PeopleSort,
) -> List(PersonStatus) {
  case sort {
    SortByName ->
      list.sort(people, fn(a, b) {
        string.compare(string.lowercase(a.label), string.lowercase(b.label))
      })
    SortByClaimedCount ->
      list.sort(people, fn(a, b) {
        int_desc(claimed_work_count(a), claimed_work_count(b))
      })
    SortByAttention ->
      list.sort(people, fn(a, b) {
        case int_desc(attention_rank(a), attention_rank(b)) {
          order.Eq ->
            string.compare(string.lowercase(a.label), string.lowercase(b.label))
          other -> other
        }
      })
  }
}

pub fn filter_from_string(value: String) -> PeopleVisibilityFilter {
  case value {
    "with-work" -> ShowWithWork
    "attention" -> ShowAttention
    "free" -> ShowFree
    _ -> ShowEveryone
  }
}

pub fn filter_to_string(filter: PeopleVisibilityFilter) -> String {
  case filter {
    ShowEveryone -> "everyone"
    ShowWithWork -> "with-work"
    ShowAttention -> "attention"
    ShowFree -> "free"
  }
}

pub fn sort_from_string(value: String) -> PeopleSort {
  case value {
    "name" -> SortByName
    "claimed" -> SortByClaimedCount
    _ -> SortByAttention
  }
}

pub fn sort_to_string(sort: PeopleSort) -> String {
  case sort {
    SortByAttention -> "attention"
    SortByName -> "name"
    SortByClaimedCount -> "claimed"
  }
}

fn attention_signals(
  tasks: List(domain_task.Task),
) -> List(PersonAttentionSignal) {
  let blocked =
    tasks
    |> list.filter_map(fn(task) {
      case task.blocked_count > 0 {
        True -> Ok(BlockedTask(task.id))
        False -> Error(Nil)
      }
    })

  let high_load = case list.length(tasks) >= load_warning_claimed_threshold {
    True -> [HighClaimedLoad(list.length(tasks))]
    False -> []
  }

  list.append(blocked, high_load)
}

fn attention_rank(person: PersonStatus) -> Int {
  case person.work_state {
    BlockedWork -> 4
    WorkingNow -> 3
    HasClaimedWork -> 2
    FreeInScope -> 1
  }
}

fn int_desc(a: Int, b: Int) -> order.Order {
  case a > b {
    True -> order.Lt
    False ->
      case a < b {
        True -> order.Gt
        False -> order.Eq
      }
  }
}

fn is_active_for_user(task: domain_task.Task, user_id: Int) -> Bool {
  case task.state {
    task_state.Claimed(claimed_by: claimed_by, mode: task_state.Ongoing, ..) ->
      claimed_by == user_id
    task_state.Available
    | task_state.Claimed(mode: task_state.Taken, ..)
    | task_state.Closed(..) -> False
  }
}

pub fn badge_variant(work_state: PersonWorkState) -> badge.BadgeVariant {
  case work_state {
    WorkingNow -> badge.Primary
    HasClaimedWork -> badge.Warning
    BlockedWork -> badge.Danger
    FreeInScope -> badge.Success
  }
}

pub fn toggle(expansion: RowExpansion) -> RowExpansion {
  case expansion {
    Expanded -> Collapsed
    Collapsed -> Expanded
  }
}
