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

import domain/card
import domain/task.{type Task, type TaskDependency, Task, TaskDependency}
import domain/task_state
import domain/task_status.{
  type OngoingBy, type TaskStatus, type WorkState, OngoingBy,
}
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import helpers/json as json_helpers
import scrumbringer_server/services/metrics_db
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
/// Story 4.9 AC15: Added tasks_count field.
pub fn task_type_json(task_type: task_types_db.TaskType) -> json.Json {
  let task_types_db.TaskType(
    id: id,
    project_id: project_id,
    name: name,
    icon: icon,
    capability_id: capability_id,
    tasks_count: tasks_count,
  ) = task_type

  json.object([
    #("id", json.int(id)),
    #("project_id", json.int(project_id)),
    #("name", json.string(name)),
    #("icon", json.string(icon)),
    #("capability_id", json_helpers.option_int_json(capability_id)),
    #("tasks_count", json.int(tasks_count)),
  ])
}

pub fn task_types_response(values: List(task_types_db.TaskType)) -> json.Json {
  json.object([#("task_types", json.array(values, of: task_type_json))])
}

pub fn task_type_response(value: task_types_db.TaskType) -> json.Json {
  json.object([#("task_type", task_type_json(value))])
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
    task_type: task_type,
    ongoing_by: ongoing_by,
    title: title,
    description: description,
    priority: priority,
    state: state,
    status: _status,
    work_state: _work_state,
    created_by: created_by,
    created_at: created_at,
    due_date: due_date,
    version: version,
    milestone_id: milestone_id,
    card_id: card_id,
    card_title: card_title,
    card_color: card_color,
    has_new_notes: has_new_notes,
    blocked_count: blocked_count,
    dependencies: dependencies,
  ) = task

  let claimed_by = task_state.claimed_by(state)
  let claimed_at = task_state.claimed_at(state)
  let completed_at = task_state.completed_at(state)
  let status = task_state.to_status(state)
  let work_state = task_state.to_work_state(state)

  json.object([
    #("id", json.int(id)),
    #("project_id", json.int(project_id)),
    #("type_id", json.int(type_id)),
    #(
      "task_type",
      json.object([
        #("id", json.int(type_id)),
        #("name", json.string(task_type.name)),
        #("icon", json.string(task_type.icon)),
      ]),
    ),
    #("ongoing_by", ongoing_by_json(ongoing_by)),
    #("title", json.string(title)),
    #("description", json_helpers.option_string_json(description)),
    #("priority", json.int(priority)),
    #("status", json.string(status_to_string(status))),
    #("work_state", json.string(work_state_to_string(work_state))),
    #("created_by", json.int(created_by)),
    #("claimed_by", json_helpers.option_int_json(claimed_by)),
    #("claimed_at", json_helpers.option_string_json(claimed_at)),
    #("completed_at", json_helpers.option_string_json(completed_at)),
    #("created_at", json.string(created_at)),
    #("due_date", json_helpers.option_string_json(due_date)),
    #("version", json.int(version)),
    #("milestone_id", json_helpers.option_int_json(milestone_id)),
    #("card_id", json_helpers.option_int_json(card_id)),
    #("card_title", json_helpers.option_string_json(card_title)),
    #("card_color", option_card_color_json(card_color)),
    // Story 5.4 AC4: Indicator for unread notes
    #("has_new_notes", json.bool(has_new_notes)),
    #("blocked_count", json.int(blocked_count)),
    #("dependencies", json.array(dependencies, of: dependency_json)),
  ])
}

pub fn tasks_response(values: List(Task)) -> json.Json {
  json.object([#("tasks", json.array(values, of: task_json))])
}

pub fn task_response(value: Task) -> json.Json {
  json.object([#("task", task_json(value))])
}

fn option_card_color_json(color: Option(card.CardColor)) -> json.Json {
  json_helpers.option_to_json(color, fn(value) {
    json.string(card.color_to_string(value))
  })
}

pub fn dependency_json(dep: TaskDependency) -> json.Json {
  let TaskDependency(
    depends_on_task_id: depends_on_task_id,
    title: title,
    status: status,
    claimed_by: claimed_by,
  ) = dep

  json.object([
    #("task_id", json.int(depends_on_task_id)),
    #("title", json.string(title)),
    #("status", json.string(status_to_string(status))),
    #("claimed_by", json_helpers.option_string_json(claimed_by)),
  ])
}

pub fn dependencies_response(values: List(TaskDependency)) -> json.Json {
  json.object([#("dependencies", json.array(values, of: dependency_json))])
}

pub fn dependency_response(value: TaskDependency) -> json.Json {
  json.object([#("dependency", dependency_json(value))])
}

pub fn task_metrics_json(metrics: metrics_db.TaskMetrics) -> json.Json {
  let metrics_db.TaskMetrics(
    claim_count: claim_count,
    release_count: release_count,
    unique_executors: unique_executors,
    first_claim_at: first_claim_at,
    current_state_duration_s: current_state_duration_s,
    pool_lifetime_s: pool_lifetime_s,
    session_count: session_count,
    total_work_time_s: total_work_time_s,
  ) = metrics

  json.object([
    #("claim_count", json.int(claim_count)),
    #("release_count", json.int(release_count)),
    #("unique_executors", json.int(unique_executors)),
    #("first_claim_at", json_helpers.option_string_json(first_claim_at)),
    #("current_state_duration_s", json.int(current_state_duration_s)),
    #("pool_lifetime_s", json.int(pool_lifetime_s)),
    #("session_count", json.int(session_count)),
    #("total_work_time_s", json.int(total_work_time_s)),
  ])
}

pub fn task_metrics_response(
  task_id: Int,
  metrics: metrics_db.TaskMetrics,
) -> json.Json {
  json.object([
    #("id", json.string(int.to_string(task_id))),
    #("metrics", task_metrics_json(metrics)),
  ])
}

/// Convert ongoing_by user_id to JSON object or null.
///
/// ## Example
///
/// ```gleam
/// ongoing_by_json(Some(123))  // {"user_id": 123}
/// ongoing_by_json(None)       // null
/// ```
pub fn ongoing_by_json(value: Option(OngoingBy)) -> json.Json {
  case value {
    None -> json.null()
    Some(OngoingBy(user_id: user_id)) ->
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
fn status_to_string(status: TaskStatus) -> String {
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
fn work_state_to_string(work_state: WorkState) -> String {
  task_status.work_state_to_string(work_state)
}
