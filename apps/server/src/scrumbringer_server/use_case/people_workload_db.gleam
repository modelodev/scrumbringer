//// Read model for project people workload.

import domain/card.{type CardPhase, Active, Closed, Draft}
import domain/people_workload.{
  type PersonWorkload, type PersonWorkloadTask, PersonWorkload,
  PersonWorkloadSummary, PersonWorkloadTask, WorkloadAttention,
  WorkloadAvailable, WorkloadReserved, WorkloadWorkingNow,
}
import domain/project_role
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/persisted_role

type Accumulator {
  Accumulator(order: List(Int), people: Dict(Int, PersonWorkload))
}

pub fn list_project_workload(
  db: pog.Connection,
  project_id: Int,
) -> Result(List(PersonWorkload), pog.QueryError) {
  use returned <- result.try(sql.people_workload_list(db, project_id))

  let acc =
    list.fold(
      returned.rows,
      Accumulator(order: [], people: dict.new()),
      fn(acc, row) { upsert_row(acc, row) },
    )

  let Accumulator(order: order, people: people) = acc

  order
  |> list.reverse
  |> list.filter_map(fn(user_id) { dict.get(people, user_id) })
  |> Ok
}

fn upsert_row(acc: Accumulator, row: sql.PeopleWorkloadListRow) -> Accumulator {
  let Accumulator(order: order, people: people) = acc
  let user_id = row.user_id

  let #(person, is_new) = case dict.get(people, user_id) {
    Ok(existing) -> #(existing, False)
    Error(_) -> #(new_person(row), True)
  }

  let next_person = case task_from_row(row) {
    Some(task) -> add_task(person, task)
    None -> person
  }

  Accumulator(
    order: case is_new {
      True -> [user_id, ..order]
      False -> order
    },
    people: dict.insert(people, user_id, finalize_person(next_person)),
  )
}

fn new_person(row: sql.PeopleWorkloadListRow) -> PersonWorkload {
  let role = case persisted_role.project_role(row.role) {
    Ok(parsed) -> parsed
    Error(_) -> project_role.Member
  }

  PersonWorkload(
    user_id: row.user_id,
    email: row.email,
    role: role,
    state: WorkloadAvailable,
    working_now: [],
    reserved: [],
    attention: [],
    summary: PersonWorkloadSummary(
      working_now_count: 0,
      reserved_count: 0,
      attention_count: 0,
    ),
  )
}

fn task_from_row(row: sql.PeopleWorkloadListRow) -> Option(PersonWorkloadTask) {
  case row.task_id <= 0 {
    True -> None
    False ->
      Some(PersonWorkloadTask(
        task_id: row.task_id,
        task_version: row.task_version,
        owner_user_id: row.task_owner_user_id,
        title: row.task_title,
        task_type_name: row.task_type_name,
        capability_name: non_empty(row.capability_name),
        card_id: positive(row.card_id),
        card_title: non_empty(row.card_title),
        card_state: card_phase(row.card_state),
        blocked: row.blocked_count > 0,
        ongoing: row.ongoing_by_user_id > 0,
        outside_active_work_scope: outside_active_work_scope(row.card_state),
      ))
  }
}

fn add_task(person: PersonWorkload, task: PersonWorkloadTask) -> PersonWorkload {
  let PersonWorkload(
    working_now: working_now,
    reserved: reserved,
    attention: attention,
    ..,
  ) = person

  case task.blocked, task.ongoing {
    True, _ -> PersonWorkload(..person, attention: [task, ..attention])
    False, True -> PersonWorkload(..person, working_now: [task, ..working_now])
    False, False -> PersonWorkload(..person, reserved: [task, ..reserved])
  }
}

fn finalize_person(person: PersonWorkload) -> PersonWorkload {
  let PersonWorkload(
    working_now: working_now,
    reserved: reserved,
    attention: attention,
    ..,
  ) = person
  let working_now = list.reverse(working_now)
  let reserved = list.reverse(reserved)
  let attention = list.reverse(attention)
  let summary =
    PersonWorkloadSummary(
      working_now_count: list.length(working_now),
      reserved_count: list.length(reserved),
      attention_count: list.length(attention),
    )

  let state = case attention, working_now, reserved {
    [_, ..], _, _ -> WorkloadAttention
    _, [_, ..], _ -> WorkloadWorkingNow
    _, _, [_, ..] -> WorkloadReserved
    _, _, _ -> WorkloadAvailable
  }

  PersonWorkload(
    ..person,
    state: state,
    working_now: working_now,
    reserved: reserved,
    attention: attention,
    summary: summary,
  )
}

fn non_empty(value: String) -> Option(String) {
  case value {
    "" -> None
    _ -> Some(value)
  }
}

fn positive(value: Int) -> Option(Int) {
  case value > 0 {
    True -> Some(value)
    False -> None
  }
}

fn card_phase(value: String) -> Option(CardPhase) {
  case value {
    "draft" -> Some(Draft)
    "active" -> Some(Active)
    "closed" -> Some(Closed)
    _ -> None
  }
}

fn outside_active_work_scope(card_state: String) -> Bool {
  case card_state {
    "" | "active" -> False
    _ -> True
  }
}
