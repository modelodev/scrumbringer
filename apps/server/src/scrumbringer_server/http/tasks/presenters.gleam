//// Task JSON presenter functions for Scrumbringer server.
////
//// ## Mission
////
//// Provides JSON serialization functions for task-related types including
//// tasks, task types, and helper functions for optional fields.
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_server/http/tasks/presenters
////
//// let json = presenters.task_json(task)
//// let json = presenters.task_type_json(task_type)
//// ```

import gleam/json
import gleam/option.{type Option, None, Some}
import scrumbringer_server/services/task_types_db
import scrumbringer_server/services/tasks_db

// =============================================================================
// Task Type JSON
// =============================================================================

/// Convert a TaskType to JSON.
///
/// ## Example
///
/// ```gleam
/// let json = task_type_json(task_type)
/// // {"id": 1, "project_id": 10, "name": "Bug", "icon": "🐛", "capability_id": null}
/// ```
pub fn task_type_json(task_type: task_types_db.TaskType) -> json.Json {
  let task_types_db.TaskType(
    id: id,
    project_id: project_id,
    name: name,
    icon: icon,
    capability_id: capability_id,
  ) = task_type

  json.object([
    #("id", json.int(id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("icon", json.string(icon)),
    #("capability_id", option_int_json(capability_id)),
  ])
}

// =============================================================================
// Task JSON
// =============================================================================

/// Convert a Task to JSON.
///
/// ## Example
///
/// ```gleam
/// let json = task_json(task)
/// ```
pub fn task_json(task: tasks_db.Task) -> json.Json {
  let tasks_db.Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    type_name: type_name,
    type_icon: type_icon,
    title: title,
    description: description,
    priority: priority,
    status: status,
    is_ongoing: is_ongoing,
    ongoing_by_user_id: ongoing_by_user_id,
    created_by: created_by,
    claimed_by: claimed_by,
    claimed_at: claimed_at,
    completed_at: completed_at,
    created_at: created_at,
    version: version,
  ) = task

  let work_state = derive_work_state(status, is_ongoing)

  json.object([
    #("id", json.int(id)),
    #("project_id", json.int(project_id)),
    #("type_id", json.int(type_id)),
    #(
      "task_type",
      json.object([
        #("id", json.int(type_id)),
        #("name", json.string(type_name)),
        #("icon", json.string(type_icon)),
      ]),
    ),
    #("ongoing_by", ongoing_by_json(ongoing_by_user_id)),
    #("title", json.string(title)),
    #("description", option_string_json(description)),
    #("priority", json.int(priority)),
    #("status", json.string(status)),
    #("work_state", json.string(work_state)),
    #("created_by", json.int(created_by)),
    #("claimed_by", option_int_json(claimed_by)),
    #("claimed_at", option_string_json(claimed_at)),
    #("completed_at", option_string_json(completed_at)),
    #("created_at", json.string(created_at)),
    #("version", json.int(version)),
  ])
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Convert optional Int to JSON (null if None).
///
/// ## Example
///
/// ```gleam
/// option_int_json(Some(42))  // json.int(42)
/// option_int_json(None)      // json.null()
/// ```
pub fn option_int_json(value: Option(Int)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.int(v)
  }
}

/// Convert optional String to JSON (null if None).
///
/// ## Example
///
/// ```gleam
/// option_string_json(Some("hello"))  // json.string("hello")
/// option_string_json(None)           // json.null()
/// ```
pub fn option_string_json(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(v) -> json.string(v)
  }
}

/// Convert ongoing_by user_id to JSON object or null.
///
/// ## Example
///
/// ```gleam
/// ongoing_by_json(Some(123))  // {"user_id": 123}
/// ongoing_by_json(None)       // null
/// ```
pub fn ongoing_by_json(value: Option(Int)) -> json.Json {
  case value {
    None -> json.null()
    Some(user_id) ->
      json.object([
        #("user_id", json.int(user_id)),
      ])
  }
}

/// Derive work_state from status and is_ongoing flag.
///
/// ## Example
///
/// ```gleam
/// derive_work_state("claimed", True)   // "ongoing"
/// derive_work_state("claimed", False)  // "claimed"
/// derive_work_state("available", _)    // "available"
/// derive_work_state("completed", _)    // "completed"
/// ```
pub fn derive_work_state(status: String, is_ongoing: Bool) -> String {
  case status {
    "available" -> "available"
    "completed" -> "completed"
    "claimed" ->
      case is_ongoing {
        True -> "ongoing"
        False -> "claimed"
      }
    _ -> status
  }
}
