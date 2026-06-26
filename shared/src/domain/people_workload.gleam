//// People workload read model shared by server and client.

import domain/card.{type CardPhase}
import domain/project_role.{type ProjectRole}
import gleam/option.{type Option}

pub type PersonWorkState {
  WorkloadAvailable
  WorkloadReserved
  WorkloadWorkingNow
  WorkloadAttention
}

pub type PersonWorkloadSummary {
  PersonWorkloadSummary(
    working_now_count: Int,
    reserved_count: Int,
    attention_count: Int,
  )
}

pub type PersonWorkloadTask {
  PersonWorkloadTask(
    task_id: Int,
    task_version: Int,
    owner_user_id: Int,
    title: String,
    task_type_name: String,
    capability_name: Option(String),
    card_id: Option(Int),
    card_title: Option(String),
    card_state: Option(CardPhase),
    blocked: Bool,
    ongoing: Bool,
  )
}

pub type PersonWorkload {
  PersonWorkload(
    user_id: Int,
    email: String,
    role: ProjectRole,
    state: PersonWorkState,
    working_now: List(PersonWorkloadTask),
    reserved: List(PersonWorkloadTask),
    attention: List(PersonWorkloadTask),
    summary: PersonWorkloadSummary,
  )
}

pub fn state_to_string(state: PersonWorkState) -> String {
  case state {
    WorkloadAvailable -> "available"
    WorkloadReserved -> "reserved"
    WorkloadWorkingNow -> "working_now"
    WorkloadAttention -> "attention"
  }
}

pub fn parse_state(value: String) -> Result(PersonWorkState, Nil) {
  case value {
    "available" -> Ok(WorkloadAvailable)
    "reserved" -> Ok(WorkloadReserved)
    "working_now" -> Ok(WorkloadWorkingNow)
    "attention" -> Ok(WorkloadAttention)
    _ -> Error(Nil)
  }
}
