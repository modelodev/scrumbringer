//// Rule target and state types for workflow rules.
////
//// These types prevent mixing task and card states while keeping the
//// underlying state values flexible (string-backed).

import gleam/option.{type Option, None, Some}

pub type TaskState {
  TaskState(String)
}

pub type CardState {
  CardState(String)
}

pub fn task_state(value: String) -> TaskState {
  TaskState(value)
}

pub fn card_state(value: String) -> CardState {
  CardState(value)
}

pub fn task_state_to_string(state: TaskState) -> String {
  let TaskState(value) = state
  value
}

pub fn card_state_to_string(state: CardState) -> String {
  let CardState(value) = state
  value
}

pub type RuleTarget {
  TaskRule(to_state: TaskState, task_type_id: Option(Int))
  CardRule(to_state: CardState)
}

pub type RuleTargetError {
  InvalidResourceType
  TaskTypeNotAllowedForCard
}

pub fn from_strings(
  resource_type: String,
  task_type_id: Int,
  to_state: String,
) -> Result(RuleTarget, RuleTargetError) {
  let task_type_opt = case task_type_id {
    id if id > 0 -> Some(id)
    _ -> None
  }

  case resource_type {
    "task" -> Ok(TaskRule(task_state(to_state), task_type_opt))
    "card" ->
      case task_type_opt {
        Some(_) -> Error(TaskTypeNotAllowedForCard)
        None -> Ok(CardRule(card_state(to_state)))
      }
    _ -> Error(InvalidResourceType)
  }
}

pub fn resource_type(target: RuleTarget) -> String {
  case target {
    TaskRule(_, _) -> "task"
    CardRule(_) -> "card"
  }
}

pub fn task_type_id(target: RuleTarget) -> Option(Int) {
  case target {
    TaskRule(_, task_type_id) -> task_type_id
    CardRule(_) -> None
  }
}

pub fn to_state_string(target: RuleTarget) -> String {
  case target {
    TaskRule(to_state, _) -> task_state_to_string(to_state)
    CardRule(to_state) -> card_state_to_string(to_state)
  }
}

pub fn to_db_values(target: RuleTarget) -> #(String, Int, String) {
  let resource_type = resource_type(target)
  let state = to_state_string(target)

  let task_type_param = case task_type_id(target) {
    Some(id) -> id
    None -> 0
  }

  #(resource_type, task_type_param, state)
}
