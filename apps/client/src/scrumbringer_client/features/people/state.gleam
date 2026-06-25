//// People feature state and derivation helpers.

import gleam/list
import gleam/option
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

pub type RosterSection {
  NeedsAttention
  RosterWorkingNow
  RosterClaimedWork
  RosterAvailable
}

pub type AttentionReason {
  OngoingWorkBlocked
  ClaimedWorkBlocked
}

pub type SecondarySignal {
  HighClaimedLoadSignal(claimed_count: Int)
}

pub type PersonRosterRow {
  PersonRosterRow(
    person: PersonStatus,
    section: RosterSection,
    primary_task: option.Option(domain_task.Task),
    attention_reason: option.Option(AttentionReason),
    secondary_signal: option.Option(SecondarySignal),
  )
}

pub type RosterSummary {
  RosterSummary(
    attention_count: Int,
    working_count: Int,
    claimed_count: Int,
    available_count: Int,
  )
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
  list.any(person.signals, fn(signal) {
    case signal {
      BlockedTask(_) -> True
      HighClaimedLoad(_) -> False
    }
  })
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

pub fn build_roster(people: List(PersonStatus)) -> List(PersonRosterRow) {
  people
  |> list.map(roster_row)
}

pub fn roster_summary(rows: List(PersonRosterRow)) -> RosterSummary {
  list.fold(
    rows,
    RosterSummary(
      attention_count: 0,
      working_count: 0,
      claimed_count: 0,
      available_count: 0,
    ),
    fn(summary, row) {
      case row.section {
        NeedsAttention ->
          RosterSummary(..summary, attention_count: summary.attention_count + 1)
        RosterWorkingNow ->
          RosterSummary(..summary, working_count: summary.working_count + 1)
        RosterClaimedWork ->
          RosterSummary(..summary, claimed_count: summary.claimed_count + 1)
        RosterAvailable ->
          RosterSummary(..summary, available_count: summary.available_count + 1)
      }
    },
  )
}

pub fn rows_in_section(
  rows: List(PersonRosterRow),
  section: RosterSection,
) -> List(PersonRosterRow) {
  list.filter(rows, fn(row) { row.section == section })
}

pub fn section_rank(section: RosterSection) -> Int {
  case section {
    NeedsAttention -> 4
    RosterWorkingNow -> 3
    RosterClaimedWork -> 2
    RosterAvailable -> 1
  }
}

fn roster_row(person: PersonStatus) -> PersonRosterRow {
  case first_blocked_task(person.active_tasks) {
    option.Some(task) ->
      PersonRosterRow(
        person: person,
        section: NeedsAttention,
        primary_task: option.Some(task),
        attention_reason: option.Some(OngoingWorkBlocked),
        secondary_signal: secondary_signal(person),
      )
    option.None ->
      case first_blocked_task(person.claimed_tasks) {
        option.Some(task) ->
          PersonRosterRow(
            person: person,
            section: NeedsAttention,
            primary_task: option.Some(task),
            attention_reason: option.Some(ClaimedWorkBlocked),
            secondary_signal: secondary_signal(person),
          )
        option.None ->
          case person.active_tasks {
            [task, ..] ->
              PersonRosterRow(
                person: person,
                section: RosterWorkingNow,
                primary_task: option.Some(task),
                attention_reason: option.None,
                secondary_signal: secondary_signal(person),
              )
            [] ->
              case person.claimed_tasks {
                [task, ..] ->
                  PersonRosterRow(
                    person: person,
                    section: RosterClaimedWork,
                    primary_task: option.Some(task),
                    attention_reason: option.None,
                    secondary_signal: secondary_signal(person),
                  )
                [] ->
                  PersonRosterRow(
                    person: person,
                    section: RosterAvailable,
                    primary_task: option.None,
                    attention_reason: option.None,
                    secondary_signal: option.None,
                  )
              }
          }
      }
  }
}

fn first_blocked_task(
  tasks: List(domain_task.Task),
) -> option.Option(domain_task.Task) {
  list.find(tasks, fn(task) { task.blocked_count > 0 })
  |> result_to_option
}

fn secondary_signal(person: PersonStatus) -> option.Option(SecondarySignal) {
  list.find_map(person.signals, fn(signal) {
    case signal {
      HighClaimedLoad(count) -> Ok(HighClaimedLoadSignal(count))
      BlockedTask(_) -> Error(Nil)
    }
  })
  |> result_to_option
}

fn result_to_option(result: Result(a, b)) -> option.Option(a) {
  case result {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
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
