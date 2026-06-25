import gleam/list
import gleam/option.{None, Some}

import domain/people_workload.{
  type PersonWorkload, type PersonWorkloadTask, PersonWorkload,
  PersonWorkloadSummary, PersonWorkloadTask, WorkloadAttention,
  WorkloadAvailable, WorkloadReserved, WorkloadWorkingNow,
}
import domain/project_role
import scrumbringer_client/features/people/state as people_state

fn task(id: Int) -> PersonWorkloadTask {
  PersonWorkloadTask(
    task_id: id,
    task_version: 1,
    owner_user_id: 10,
    title: "Task",
    task_type_name: "Bug",
    capability_name: None,
    card_id: None,
    card_title: None,
    card_state: None,
    blocked: False,
    ongoing: False,
    outside_active_work_scope: False,
  )
}

fn blocked(task: PersonWorkloadTask) -> PersonWorkloadTask {
  PersonWorkloadTask(..task, blocked: True)
}

fn ongoing(task: PersonWorkloadTask) -> PersonWorkloadTask {
  PersonWorkloadTask(..task, ongoing: True)
}

fn person(
  working_now working_now: List(PersonWorkloadTask),
  reserved reserved: List(PersonWorkloadTask),
  attention attention: List(PersonWorkloadTask),
) -> PersonWorkload {
  let state = case attention, working_now, reserved {
    [_, ..], _, _ -> WorkloadAttention
    _, [_, ..], _ -> WorkloadWorkingNow
    _, _, [_, ..] -> WorkloadReserved
    _, _, _ -> WorkloadAvailable
  }

  PersonWorkload(
    user_id: 10,
    email: "ana@example.com",
    role: project_role.Member,
    state: state,
    working_now: working_now,
    reserved: reserved,
    attention: attention,
    summary: PersonWorkloadSummary(
      working_now_count: list.length(working_now),
      reserved_count: list.length(reserved),
      attention_count: list.length(attention),
    ),
  )
}

pub fn roster_reserved_work_uses_reserved_section_test() {
  let p = person(working_now: [], reserved: [task(1)], attention: [])

  let assert [row] = people_state.build_roster([p])
  let assert people_state.RosterReservedWork = row.section
  let assert Some(primary) = row.primary_task
  let assert 1 = primary.task_id
}

pub fn roster_reserved_blocked_goes_to_attention_test() {
  let p = person(working_now: [], reserved: [], attention: [task(1) |> blocked])

  let assert [row] = people_state.build_roster([p])
  let assert people_state.NeedsAttention = row.section
  let assert Some(people_state.ReservedWorkBlocked) = row.attention_reason
}

pub fn roster_ongoing_blocked_goes_to_attention_test() {
  let p =
    person(working_now: [], reserved: [], attention: [
      task(1) |> ongoing |> blocked,
    ])

  let assert [row] = people_state.build_roster([p])
  let assert people_state.NeedsAttention = row.section
  let assert Some(people_state.OngoingWorkBlocked) = row.attention_reason
}

pub fn roster_available_has_no_primary_task_test() {
  let p = person(working_now: [], reserved: [], attention: [])

  let assert [row] = people_state.build_roster([p])
  let assert people_state.RosterAvailable = row.section
  let assert None = row.primary_task
  let assert None = row.attention_reason
}

pub fn roster_high_load_stays_reserved_work_with_secondary_signal_test() {
  let p =
    person(
      working_now: [],
      reserved: [task(1), task(2), task(3), task(4)],
      attention: [],
    )

  let assert [row] = people_state.build_roster([p])
  let assert people_state.RosterReservedWork = row.section
  let assert Some(people_state.HighReservedLoadSignal(4)) = row.secondary_signal
  let assert False = people_state.has_attention(p)
}

pub fn roster_unblocked_ongoing_goes_to_working_now_test() {
  let p = person(working_now: [task(1) |> ongoing], reserved: [], attention: [])

  let assert [row] = people_state.build_roster([p])
  let assert people_state.RosterWorkingNow = row.section
}
