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
import domain/task_status.{
  type TaskStatus, Available, Claimed, Completed, Ongoing, Taken,
}
import helpers/json as json_helpers
import scrumbringer_server/persistence/tasks/mappers.{type Task, Task}
import scrumbringer_server/services/task_types_db

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
pub fn task_json(task: Task) -> json.Json {
  let Task(
    id: id,
    project_id: project_id,
    type_id: type_id,
    type_name: type_name,
    type_icon: type_icon,
    title: title,
    description: description,
    priority: priority,
    status: status,
    ongoing_by_user_id: ongoing_by_user_id,
    created_by: created_by,
    claimed_by: claimed_by,
    claimed_at: claimed_at,
    completed_at: completed_at,
    created_at: created_at,
    version: version,
    card_id: card_id,
    card_title: card_title,
    card_color: card_color,
  ) = task

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
    #("status", json.string(status_to_string(status))),
    #("work_state", json.string(status_to_work_state(status))),
    #("created_by", json.int(created_by)),
    #("claimed_by", option_int_json(claimed_by)),
    #("claimed_at", option_string_json(claimed_at)),
    #("completed_at", option_string_json(completed_at)),
    #("created_at", json.string(created_at)),
    #("version", json.int(version)),
    #("card_id", option_int_json(card_id)),
    #("card_title", option_string_json(card_title)),
    #("card_color", option_string_json(card_color)),
  ])
}

// =============================================================================
// Helper Functions (re-exported from shared/helpers/json)
// =============================================================================

/// Convert optional Int to JSON (null if None).
/// Re-exported from shared/helpers/json for backwards compatibility.
pub const option_int_json = json_helpers.option_int_json

/// Convert optional String to JSON (null if None).
/// Re-exported from shared/helpers/json for backwards compatibility.
pub const option_string_json = json_helpers.option_string_json

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

/// Convert TaskStatus to database status string for JSON output.
///
/// ## Example
///
/// ```gleam
/// status_to_string(Available)        // "available"
/// status_to_string(Claimed(Taken))   // "claimed"
/// status_to_string(Claimed(Ongoing)) // "claimed"
/// status_to_string(Completed)        // "completed"
/// ```
pub fn status_to_string(status: TaskStatus) -> String {
  task_status.to_db_status(status)
}

/// Convert TaskStatus to work_state string for JSON output.
///
/// The work_state provides more granular information than status,
/// distinguishing between "claimed" (idle) and "ongoing" (active work).
///
/// ## Example
///
/// ```gleam
/// status_to_work_state(Available)        // "available"
/// status_to_work_state(Claimed(Taken))   // "claimed"
/// status_to_work_state(Claimed(Ongoing)) // "ongoing"
/// status_to_work_state(Completed)        // "completed"
/// ```
pub fn status_to_work_state(status: TaskStatus) -> String {
  case status {
    Available -> "available"
    Claimed(Taken) -> "claimed"
    Claimed(Ongoing) -> "ongoing"
    Completed -> "completed"
  }
}
