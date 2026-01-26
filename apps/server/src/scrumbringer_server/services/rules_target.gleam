//// Rule target types for workflow rules.
////
//// ## Mission
////
//// Provide typed rule targets for task and card rules.
////
//// ## Responsibilities
////
//// - Parse and validate target inputs
//// - Convert targets to DB-friendly values
////
//// ## Non-responsibilities
////
//// - Rule persistence (see `services/rules_db.gleam`)
//// - Rule evaluation (see `services/rules_engine.gleam`)
////
//// ## Relationships
////
//// - Used by `services/rules_db.gleam` and `services/rules_engine.gleam`

import gleam/option.{type Option, None, Some}

/// Target for a rule (task or card).
pub type RuleTarget {
  TaskRule(to_state: String, task_type_id: Option(Int))
  CardRule(to_state: String)
}

/// Errors returned when parsing rule targets.
pub type RuleTargetError {
  InvalidResourceType
  TaskTypeNotAllowedForCard
}

// Justification: nested case improves clarity for branching logic.
/// Parses a rule target from DB string values.
///
/// Example:
///   from_strings("task", 0, "claimed")
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
    "task" -> Ok(TaskRule(to_state, task_type_opt))
    "card" ->
      // Justification: nested case prevents task types on card rules.
      case task_type_opt {
        Some(_) -> Error(TaskTypeNotAllowedForCard)
        None -> Ok(CardRule(to_state))
      }
    _ -> Error(InvalidResourceType)
  }
}

/// Returns the resource type string for a target.
///
/// Example:
///   resource_type(TaskRule("claimed", None))
pub fn resource_type(target: RuleTarget) -> String {
  case target {
    TaskRule(_, _) -> "task"
    CardRule(_) -> "card"
  }
}

/// Returns the optional task type id for a target.
///
/// Example:
///   task_type_id(CardRule("ready"))
pub fn task_type_id(target: RuleTarget) -> Option(Int) {
  case target {
    TaskRule(_, task_type_id) -> task_type_id
    CardRule(_) -> None
  }
}

/// Returns the state string for a target.
///
/// Example:
///   to_state_string(TaskRule("claimed", None))
pub fn to_state_string(target: RuleTarget) -> String {
  case target {
    TaskRule(to_state, _) -> to_state
    CardRule(to_state) -> to_state
  }
}

/// Returns DB tuple values for a target.
///
/// Example:
///   to_db_values(TaskRule("claimed", Some(1)))
pub fn to_db_values(target: RuleTarget) -> #(String, Int, String) {
  let resource_type = resource_type(target)
  let state = to_state_string(target)

  let task_type_param = case task_type_id(target) {
    Some(id) -> id
    None -> 0
  }

  #(resource_type, task_type_param, state)
}
