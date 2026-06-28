//// People feature state and workload helpers.

import domain/people_workload.{
  type PersonWorkload, type PersonWorkloadTask, WorkloadAttention,
  WorkloadAvailable, WorkloadReserved, WorkloadWorkingNow,
}
import gleam/list
import gleam/option
import gleam/order
import gleam/string

const load_warning_reserved_threshold = 4

pub type PeopleVisibilityFilter {
  ShowEveryone
  ShowWithWork
  ShowAttention
  ShowFree
}

pub type PeopleSort {
  SortByAttention
  SortByName
  SortByReservedCount
}

pub type RosterSection {
  NeedsAttention
  RosterWorkingNow
  RosterReservedWork
  RosterAvailable
}

pub type AttentionReason {
  OngoingWorkBlocked
  ReservedWorkBlocked
}

pub type SecondarySignal {
  HighReservedLoadSignal(reserved_count: Int)
}

pub type PersonRosterRow {
  PersonRosterRow(
    person: PersonWorkload,
    section: RosterSection,
    primary_task: option.Option(PersonWorkloadTask),
    attention_reason: option.Option(AttentionReason),
    secondary_signal: option.Option(SecondarySignal),
  )
}

pub type RosterSummary {
  RosterSummary(
    attention_count: Int,
    working_count: Int,
    reserved_count: Int,
    available_count: Int,
  )
}

pub type RowExpansion {
  Expanded
  Collapsed
}

pub fn has_work(person: PersonWorkload) -> Bool {
  person.working_now != [] || person.reserved != [] || person.attention != []
}

pub fn has_attention(person: PersonWorkload) -> Bool {
  person.attention != []
}

fn reserved_work_count(person: PersonWorkload) -> Int {
  list.length(person.working_now)
  + list.length(person.reserved)
  + list.length(person.attention)
}

pub fn apply_visibility_filter(
  people: List(PersonWorkload),
  filter: PeopleVisibilityFilter,
) -> List(PersonWorkload) {
  case filter {
    ShowEveryone -> people
    ShowWithWork -> list.filter(people, has_work)
    ShowAttention -> list.filter(people, has_attention)
    ShowFree -> list.filter(people, fn(person) { !has_work(person) })
  }
}

pub fn sort_people(
  people: List(PersonWorkload),
  sort: PeopleSort,
) -> List(PersonWorkload) {
  case sort {
    SortByName ->
      list.sort(people, fn(a, b) {
        string.compare(string.lowercase(a.email), string.lowercase(b.email))
      })
    SortByReservedCount ->
      list.sort(people, fn(a, b) {
        int_desc(reserved_work_count(a), reserved_work_count(b))
      })
    SortByAttention ->
      list.sort(people, fn(a, b) {
        case int_desc(attention_rank(a), attention_rank(b)) {
          order.Eq ->
            string.compare(string.lowercase(a.email), string.lowercase(b.email))
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
    "reserved" -> SortByReservedCount
    _ -> SortByAttention
  }
}

pub fn sort_to_string(sort: PeopleSort) -> String {
  case sort {
    SortByAttention -> "attention"
    SortByName -> "name"
    SortByReservedCount -> "reserved"
  }
}

pub fn build_roster(people: List(PersonWorkload)) -> List(PersonRosterRow) {
  people
  |> list.map(roster_row)
}

pub fn roster_summary(rows: List(PersonRosterRow)) -> RosterSummary {
  list.fold(
    rows,
    RosterSummary(
      attention_count: 0,
      working_count: 0,
      reserved_count: 0,
      available_count: 0,
    ),
    fn(summary, row) {
      case row.section {
        NeedsAttention ->
          RosterSummary(..summary, attention_count: summary.attention_count + 1)
        RosterWorkingNow ->
          RosterSummary(..summary, working_count: summary.working_count + 1)
        RosterReservedWork ->
          RosterSummary(..summary, reserved_count: summary.reserved_count + 1)
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

fn roster_row(person: PersonWorkload) -> PersonRosterRow {
  case person.attention {
    [task, ..] ->
      PersonRosterRow(
        person: person,
        section: NeedsAttention,
        primary_task: option.Some(task),
        attention_reason: case task.ongoing {
          True -> option.Some(OngoingWorkBlocked)
          False -> option.Some(ReservedWorkBlocked)
        },
        secondary_signal: secondary_signal(person),
      )
    [] ->
      case person.working_now {
        [task, ..] ->
          PersonRosterRow(
            person: person,
            section: RosterWorkingNow,
            primary_task: option.Some(task),
            attention_reason: option.None,
            secondary_signal: secondary_signal(person),
          )
        [] ->
          case person.reserved {
            [task, ..] ->
              PersonRosterRow(
                person: person,
                section: RosterReservedWork,
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

fn secondary_signal(person: PersonWorkload) -> option.Option(SecondarySignal) {
  let count = reserved_work_count(person)
  case count >= load_warning_reserved_threshold {
    True -> option.Some(HighReservedLoadSignal(count))
    False -> option.None
  }
}

fn attention_rank(person: PersonWorkload) -> Int {
  case person.state {
    WorkloadAttention -> 4
    WorkloadWorkingNow -> 3
    WorkloadReserved -> 2
    WorkloadAvailable -> 1
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

pub fn toggle(expansion: RowExpansion) -> RowExpansion {
  case expansion {
    Expanded -> Collapsed
    Collapsed -> Expanded
  }
}
